class_name Board
extends RefCounted
## Board logic: slides, merges, spawns, bounded undo and serialization.
## Tiles keep stable ids, so a view can animate the same tile through a move and its undo.

enum Dir { UP, DOWN, LEFT, RIGHT }

const MIN_SIZE := 3
const MAX_SIZE := 6
const DEFAULT_SIZE := 4
## Largest undo history the game offers; [member undo_limit] is clamped to 0..MAX_UNDO.
const MAX_UNDO := 5
const DEFAULT_UNDO := 1
const SPAWN_FOUR_CHANCE := 0.1
const FIRST_MILESTONE := 128


## Everything a view needs to replay one move.
class MoveResult:
	extends RefCounted
	var moved := false
	var gained := 0
	## Each entry: [tile_id, from_index, to_index]. Includes tiles that end up consumed by a merge.
	var slides: Array[PackedInt32Array] = []
	## Each entry: [survivor_id, consumed_id, index, new_value].
	var merges: Array[PackedInt64Array] = []
	## [tile_id, index, value], empty when nothing spawned.
	var spawn := PackedInt32Array()
	## Milestone values (powers of two >= FIRST_MILESTONE) reached for the first time this game.
	var milestones := PackedInt64Array()


## Side length; fixed per board instance (see [method new_game] to change it).
var size := DEFAULT_SIZE
var cell_count := DEFAULT_SIZE * DEFAULT_SIZE
## Tile values are 64-bit: a 6x6 board can reach 2^37, past the range of 32-bit integers.
var values := PackedInt64Array()
var ids := PackedInt32Array()
var score := 0
var best_tile := 0
var move_count := 0
var rng := RandomNumberGenerator.new()
## How many moves can be undone in a row (0 disables undo). Lowering it drops the oldest steps.
var undo_limit := DEFAULT_UNDO:
	set(v):
		undo_limit = clampi(v, 0, MAX_UNDO)
		while _undo_stack.size() > undo_limit:
			_undo_stack.pop_front()

var _next_id := 1
## Snapshots before each recent move, oldest first.
var _undo_stack: Array[Dictionary] = []


func _init(seed_value: int = -1, p_size := DEFAULT_SIZE) -> void:
	_resize(p_size)
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


static func is_valid_size(n: int) -> bool:
	return n >= MIN_SIZE and n <= MAX_SIZE


## Clears the board and places the two opening tiles. [param p_size] changes the side length.
func new_game(p_size := -1) -> void:
	if p_size > 0:
		_resize(p_size)
	values.fill(0)
	ids.fill(0)
	score = 0
	best_tile = 0
	move_count = 0
	_undo_stack.clear()
	_spawn_random()
	_spawn_random()


func index_of(x: int, y: int) -> int:
	return y * size + x


func empty_count() -> int:
	return values.count(0)


func can_undo() -> bool:
	return undo_limit > 0 and not _undo_stack.is_empty()


## Moves that can currently be undone, never more than were made this game.
func undo_available() -> int:
	return mini(_undo_stack.size(), undo_limit)


## True while at least one move would change the board.
func can_move() -> bool:
	for y in size:
		for x in size:
			var v := values[index_of(x, y)]
			if v == 0:
				return true
			if x + 1 < size and values[index_of(x + 1, y)] == v:
				return true
			if y + 1 < size and values[index_of(x, y + 1)] == v:
				return true
	return false


## Plays a move in [param dir]: spawns a tile and records undo when the board changes.
## [code]moved[/code] is false and nothing changes for a no-op.
func move(dir: Dir) -> MoveResult:
	var slid := _slide(dir, values, ids)
	var result: MoveResult = slid.result
	if not result.moved:
		return result
	if undo_limit > 0:
		var snapshot := _snapshot()
		snapshot.dir = dir
		_undo_stack.push_back(snapshot)
		while _undo_stack.size() > undo_limit:
			_undo_stack.pop_front()
	var prev_best := best_tile
	values = slid.values
	ids = slid.ids
	for m in result.merges:
		best_tile = maxi(best_tile, m[3])
	score += result.gained
	move_count += 1
	var milestone := maxi(FIRST_MILESTONE, _next_power_of_two(prev_best + 1))
	while milestone <= best_tile:
		result.milestones.append(milestone)
		milestone *= 2
	result.spawn = _spawn_random()
	return result


## Steps back one move. Returns it with the restored tile ids so a view can play it backwards,
## with [code]moved == false[/code] when it cannot be rebuilt (old saves), or null with nothing
## to undo.
func undo() -> MoveResult:
	if not can_undo():
		return null
	var snap: Dictionary = _undo_stack.pop_back()
	var undone := _reconstruct(snap)
	values = snap.values
	score = snap.score
	best_tile = snap.best_tile
	move_count = snap.move_count
	if snap.ids.is_empty():
		_reissue_ids()
	else:
		ids = snap.ids
	return undone


## Serializable form of the full state, including the undo history.
func to_dict() -> Dictionary:
	var d := {
		"size": size,
		"values": Array(values),
		"ids": Array(ids),
		"score": score,
		"best_tile": best_tile,
		"moves": move_count,
	}
	var stack := []
	for snap in _undo_stack:
		var u := {
			"size": size,
			"values": Array(snap.values),
			"score": snap.score,
			"best_tile": snap.best_tile,
			"moves": snap.move_count,
		}
		if not snap.ids.is_empty():
			u["ids"] = Array(snap.ids)
			u["dir"] = snap.dir
		stack.append(u)
	if not stack.is_empty():
		d["undo_stack"] = stack
	return d


## Loads [method to_dict] output (or a 1.x save). Returns false and leaves the board untouched
## on malformed data. Missing tile ids are reissued; undo then works without animation.
func from_dict(d: Dictionary) -> bool:
	var n := int(d.get("size", 0)) if (d.get("size") is int or d.get("size") is float) else 0
	if not is_valid_size(n):
		return false
	var main := _parse_state(d, n)
	if main.is_empty():
		return false
	var raw_stack: Array = []
	if d.has("undo_stack"):
		if not d.undo_stack is Array:
			return false
		raw_stack = d.undo_stack
	elif d.has("undo"):
		raw_stack = [d.undo]
	var stack: Array[Dictionary] = []
	for entry in raw_stack:
		if not entry is Dictionary:
			return false
		var parsed := _parse_state(entry, n)
		if parsed.is_empty():
			return false
		stack.append(parsed)
	while stack.size() > MAX_UNDO:
		stack.pop_front()

	_resize(n)
	values = main.values
	score = main.score
	best_tile = main.best_tile
	move_count = main.move_count
	_undo_stack = stack
	while _undo_stack.size() > undo_limit:
		_undo_stack.pop_front()
	if main.ids.is_empty():
		_reissue_ids()
		for snap in _undo_stack:
			snap.ids = PackedInt32Array()
	else:
		ids = main.ids
		_next_id = 1
		for id in ids:
			_next_id = maxi(_next_id, id + 1)
		for snap in _undo_stack:
			for id in snap.ids:
				_next_id = maxi(_next_id, id + 1)
	return true


func _resize(n: int) -> void:
	size = clampi(n, MIN_SIZE, MAX_SIZE)
	cell_count = size * size
	values.resize(cell_count)
	ids.resize(cell_count)
	values.fill(0)
	ids.fill(0)
	_undo_stack.clear()


func _snapshot() -> Dictionary:
	return {
		"values": values.duplicate(),
		"ids": ids.duplicate(),
		"dir": -1,
		"score": score,
		"best_tile": best_tile,
		"move_count": move_count,
	}


## Replays the move stored in [param snap] and checks it lands on the current board; returns an
## empty (non-animatable) result when it does not.
func _reconstruct(snap: Dictionary) -> MoveResult:
	var none := MoveResult.new()
	if snap.ids.is_empty() or snap.dir < 0 or snap.dir > Dir.RIGHT:
		return none
	var slid := _slide(snap.dir, snap.values, snap.ids)
	var result: MoveResult = slid.result
	if not result.moved:
		return none
	var spawn_index := -1
	for i in cell_count:
		if slid.values[i] == 0 and values[i] != 0:
			if spawn_index >= 0:
				return none
			spawn_index = i
		elif slid.values[i] != values[i] or (values[i] != 0 and slid.ids[i] != ids[i]):
			return none
	if spawn_index >= 0:
		result.spawn = PackedInt32Array([ids[spawn_index], spawn_index, values[spawn_index]])
	return result


## Slides and merges one move over the grid without touching the board.
## Returns {values, ids, result}; result has no spawn or milestones yet.
func _slide(dir: Dir, src_values: PackedInt64Array, src_ids: PackedInt32Array) -> Dictionary:
	var result := MoveResult.new()
	var new_values := PackedInt64Array()
	new_values.resize(cell_count)
	var new_ids := PackedInt32Array()
	new_ids.resize(cell_count)
	for line in size:
		var cells := _line_cells(dir, line)
		var write := 0
		var last_value := 0
		var last_id := 0
		for read in size:
			var src := cells[read]
			var v := src_values[src]
			if v == 0:
				continue
			var id := src_ids[src]
			if last_value == v:
				var dst := cells[write - 1]
				var merged := v * 2
				new_values[dst] = merged
				result.slides.append(PackedInt32Array([id, src, dst]))
				result.merges.append(PackedInt64Array([last_id, id, dst, merged]))
				result.gained += merged
				last_value = 0
			else:
				var dst := cells[write]
				new_values[dst] = v
				new_ids[dst] = id
				if dst != src:
					result.slides.append(PackedInt32Array([id, src, dst]))
				last_value = v
				last_id = id
				write += 1
	result.moved = not result.slides.is_empty()
	return {"values": new_values, "ids": new_ids, "result": result}


func _parse_state(d: Dictionary, n: int) -> Dictionary:
	if int(d.get("size", 0)) != n:
		return {}
	var cells := n * n
	var raw = d.get("values")
	if not (raw is Array or raw is PackedInt32Array or raw is PackedInt64Array) or raw.size() != cells:
		return {}
	var parsed := PackedInt64Array()
	parsed.resize(cells)
	var max_value := 0
	for i in cells:
		if not (raw[i] is int or raw[i] is float):
			return {}
		var v := int(raw[i])
		if v < 0 or (v != 0 and (v < 2 or (v & (v - 1)) != 0)):
			return {}
		parsed[i] = v
		max_value = maxi(max_value, v)
	var s := int(d.get("score", -1))
	var m := int(d.get("moves", -1))
	if s < 0 or m < 0:
		return {}
	var dir = d.get("dir", -1)
	return {
		"values": parsed,
		"ids": _parse_ids(d.get("ids"), parsed),
		"dir": int(dir) if (dir is int or dir is float) else -1,
		"score": s,
		"best_tile": maxi(int(d.get("best_tile", 0)), max_value),
		"move_count": m,
	}


## Tile ids aligned with [param cells]: positive and unique exactly where a tile is. Returns an
## empty array when missing or inconsistent, which callers treat as "reissue".
static func _parse_ids(raw, cells: PackedInt64Array) -> PackedInt32Array:
	if not (raw is Array or raw is PackedInt32Array) or raw.size() != cells.size():
		return PackedInt32Array()
	var parsed := PackedInt32Array()
	parsed.resize(cells.size())
	var seen := {}
	for i in cells.size():
		if not (raw[i] is int or raw[i] is float):
			return PackedInt32Array()
		var id := int(raw[i])
		if (id > 0) != (cells[i] != 0) or (id > 0 and seen.has(id)):
			return PackedInt32Array()
		seen[id] = true
		parsed[i] = id
	return parsed


func _reissue_ids() -> void:
	ids.fill(0)
	for i in cell_count:
		if values[i] != 0:
			ids[i] = _take_id()


func _take_id() -> int:
	var id := _next_id
	_next_id += 1
	return id


## Cells of one row/column ordered from the edge tiles slide towards.
func _line_cells(dir: Dir, line: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	cells.resize(size)
	for k in size:
		match dir:
			Dir.LEFT:
				cells[k] = index_of(k, line)
			Dir.RIGHT:
				cells[k] = index_of(size - 1 - k, line)
			Dir.UP:
				cells[k] = index_of(line, k)
			Dir.DOWN:
				cells[k] = index_of(line, size - 1 - k)
	return cells


func _spawn_random() -> PackedInt32Array:
	var free := PackedInt32Array()
	for i in cell_count:
		if values[i] == 0:
			free.append(i)
	if free.is_empty():
		return PackedInt32Array()
	var idx := free[rng.randi_range(0, free.size() - 1)]
	var v := 4 if rng.randf() < SPAWN_FOUR_CHANCE else 2
	var id := _take_id()
	values[idx] = v
	ids[idx] = id
	best_tile = maxi(best_tile, v)
	return PackedInt32Array([id, idx, v])


static func _next_power_of_two(n: int) -> int:
	var p := 1
	while p < n:
		p *= 2
	return p
