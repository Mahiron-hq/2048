class_name Board
extends RefCounted
## Pure 2048-style board logic: slides, merges, spawns, undo snapshot and serialization.
##
## Tiles carry stable integer ids so a view can animate the same tile across a move.
## Nothing here depends on frame time; a move is a discrete, instantaneous state change.

enum Dir { UP, DOWN, LEFT, RIGHT }

const SIZE := 4
const CELL_COUNT := SIZE * SIZE
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
	var merges: Array[PackedInt32Array] = []
	## [tile_id, index, value], empty when nothing spawned.
	var spawn := PackedInt32Array()
	## Milestone values (powers of two >= FIRST_MILESTONE) reached for the first time this game.
	var milestones := PackedInt32Array()


var values := PackedInt32Array()
var ids := PackedInt32Array()
var score := 0
var best_tile := 0
var move_count := 0
var rng := RandomNumberGenerator.new()

var _next_id := 1
var _undo: Dictionary = {}


func _init(seed_value: int = -1) -> void:
	values.resize(CELL_COUNT)
	ids.resize(CELL_COUNT)
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


## Clears the board and places the two opening tiles.
func new_game() -> void:
	values.fill(0)
	ids.fill(0)
	score = 0
	best_tile = 0
	move_count = 0
	_undo = {}
	_spawn_random()
	_spawn_random()


static func index_of(x: int, y: int) -> int:
	return y * SIZE + x


func empty_count() -> int:
	return values.count(0)


func can_undo() -> bool:
	return not _undo.is_empty()


## True while at least one move would change the board.
func can_move() -> bool:
	for y in SIZE:
		for x in SIZE:
			var v := values[index_of(x, y)]
			if v == 0:
				return true
			if x + 1 < SIZE and values[index_of(x + 1, y)] == v:
				return true
			if y + 1 < SIZE and values[index_of(x, y + 1)] == v:
				return true
	return false


## Applies a move in [param dir]. When the board changes, a new tile is spawned and the
## previous state becomes the single undo step. Returns what happened; [code]moved[/code]
## is false (and nothing is mutated) when the move is a no-op.
func move(dir: Dir) -> MoveResult:
	var result := MoveResult.new()
	var snapshot := _snapshot()
	var prev_best := best_tile
	var new_values := PackedInt32Array()
	new_values.resize(CELL_COUNT)
	var new_ids := PackedInt32Array()
	new_ids.resize(CELL_COUNT)

	for line in SIZE:
		var cells := _line_cells(dir, line)
		var write := 0
		var last_value := 0
		var last_id := 0
		for read in SIZE:
			var src := cells[read]
			var v := values[src]
			if v == 0:
				continue
			var id := ids[src]
			if last_value == v:
				var dst := cells[write - 1]
				var merged := v * 2
				new_values[dst] = merged
				result.slides.append(PackedInt32Array([id, src, dst]))
				result.merges.append(PackedInt32Array([last_id, id, dst, merged]))
				result.gained += merged
				best_tile = maxi(best_tile, merged)
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
	if not result.moved:
		best_tile = prev_best
		return result

	values = new_values
	ids = new_ids
	score += result.gained
	move_count += 1
	_undo = snapshot
	var milestone := maxi(FIRST_MILESTONE, _next_power_of_two(prev_best + 1))
	while milestone <= best_tile:
		result.milestones.append(milestone)
		milestone *= 2
	result.spawn = _spawn_random()
	return result


## Restores the state before the last successful move. Tile ids are reissued, so a view
## should rebuild rather than animate. Returns false when there is nothing to undo.
func undo() -> bool:
	if _undo.is_empty():
		return false
	values = _undo.values
	score = _undo.score
	best_tile = _undo.best_tile
	move_count = _undo.move_count
	_undo = {}
	_reissue_ids()
	return true


## Serializable form of the full state, including the pending undo step.
func to_dict() -> Dictionary:
	var d := {
		"size": SIZE,
		"values": Array(values),
		"score": score,
		"best_tile": best_tile,
		"moves": move_count,
	}
	if not _undo.is_empty():
		d["undo"] = {
			"size": SIZE,
			"values": Array(_undo.values),
			"score": _undo.score,
			"best_tile": _undo.best_tile,
			"moves": _undo.move_count,
		}
	return d


## Loads state produced by [method to_dict]. Returns false, leaving the board untouched,
## when the data is malformed (wrong size, non power-of-two values, negative counters).
func from_dict(d: Dictionary) -> bool:
	var main := _parse_state(d)
	if main.is_empty():
		return false
	var undo_state := {}
	if d.has("undo"):
		if not d.undo is Dictionary:
			return false
		undo_state = _parse_state(d.undo)
		if undo_state.is_empty():
			return false
	values = main.values
	score = main.score
	best_tile = main.best_tile
	move_count = main.move_count
	_undo = undo_state
	_reissue_ids()
	return true


func _snapshot() -> Dictionary:
	return {
		"values": values.duplicate(),
		"score": score,
		"best_tile": best_tile,
		"move_count": move_count,
	}


func _parse_state(d: Dictionary) -> Dictionary:
	if int(d.get("size", 0)) != SIZE:
		return {}
	var raw = d.get("values")
	if not (raw is Array or raw is PackedInt32Array) or raw.size() != CELL_COUNT:
		return {}
	var parsed := PackedInt32Array()
	parsed.resize(CELL_COUNT)
	var max_value := 0
	for i in CELL_COUNT:
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
	return {
		"values": parsed,
		"score": s,
		"best_tile": maxi(int(d.get("best_tile", 0)), max_value),
		"move_count": m,
	}


func _reissue_ids() -> void:
	ids.fill(0)
	for i in CELL_COUNT:
		if values[i] != 0:
			ids[i] = _take_id()


func _take_id() -> int:
	var id := _next_id
	_next_id += 1
	return id


## Cells of one row/column ordered from the edge tiles slide towards.
func _line_cells(dir: Dir, line: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	cells.resize(SIZE)
	for k in SIZE:
		match dir:
			Dir.LEFT:
				cells[k] = index_of(k, line)
			Dir.RIGHT:
				cells[k] = index_of(SIZE - 1 - k, line)
			Dir.UP:
				cells[k] = index_of(line, k)
			Dir.DOWN:
				cells[k] = index_of(line, SIZE - 1 - k)
	return cells


func _spawn_random() -> PackedInt32Array:
	var free := PackedInt32Array()
	for i in CELL_COUNT:
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
