class_name HintSolver
extends RefCounted
## Picks the strongest move with expectimax search: the player's moves against every spawn,
## leaves scored with nneonneo's row heuristic (empty cells, merges, monotonic rows).
## Deepens until the time budget runs out, so faster phones look further ahead.
## Keeps caches between calls: one instance per thread.

const LOST_PENALTY := 200000.0
const MONOTONICITY_POWER := 4.0
const MONOTONICITY_WEIGHT := 47.0
const SUM_POWER := 3.5
const SUM_WEIGHT := 11.0
const MERGES_WEIGHT := 700.0
const EMPTY_WEIGHT := 270.0
## Chance branches less likely than this are scored by the heuristic instead of searched.
const MIN_PROBABILITY := 0.0001
const SPAWN_FOUR_CHANCE := 0.1
const MAX_DEPTH := 12
## Moves in the order they are preferred when two score the same.
const ORDER := [Board.Dir.LEFT, Board.Dir.DOWN, Board.Dir.RIGHT, Board.Dir.UP]

## Deepest search that completed in the last [method best_move] call.
var last_depth := 0

var _size := 0
## Cell indices of every line per direction, ordered towards the edge tiles slide to.
var _lines := {}
## Heuristic score per packed line of ranks.
var _line_scores := {}
## Expectimax value per board state for the search in progress: {state: [depth, value]}.
var _memo := {}
var _deadline := 0
var _timed_out := false


## Best [enum Board.Dir] for [param values] on a [param size] board within about
## [param budget_ms] ms, or -1 when no move changes the board.
func best_move(values: PackedInt64Array, size: int, budget_ms: int) -> int:
	_prepare(size)
	var state := _ranks(values)
	var moves := {}
	for dir: Board.Dir in ORDER:
		var moved := _move(state, dir)
		if moved != state:
			moves[dir] = moved
	last_depth = 0
	if moves.is_empty():
		return -1
	var best: int = moves.keys()[0]
	if moves.size() == 1:
		return best
	_deadline = Time.get_ticks_usec() + budget_ms * 1000
	_timed_out = false
	for depth in range(1, MAX_DEPTH + 1):
		_memo.clear()
		var depth_best := -1
		var depth_value := -INF
		for dir: int in moves:
			var value := _chance(moves[dir], depth, 1.0)
			if _timed_out:
				break
			if value > depth_value:
				depth_value = value
				depth_best = dir
		if _timed_out:
			break
		best = depth_best
		last_depth = depth
		if Time.get_ticks_usec() >= _deadline:
			break
	_memo.clear()
	return best


## Heuristic value of a board, larger is better; exposed for tests.
func evaluate(values: PackedInt64Array, size: int) -> float:
	_prepare(size)
	return _evaluate(_ranks(values))


func _prepare(size: int) -> void:
	if size == _size:
		return
	_size = size
	_lines.clear()
	_line_scores.clear()
	for dir: Board.Dir in ORDER:
		var lines: Array[PackedInt32Array] = []
		for line in size:
			var cells := PackedInt32Array()
			for k in size:
				match dir:
					Board.Dir.LEFT:
						cells.append(line * size + k)
					Board.Dir.RIGHT:
						cells.append(line * size + size - 1 - k)
					Board.Dir.UP:
						cells.append(k * size + line)
					Board.Dir.DOWN:
						cells.append((size - 1 - k) * size + line)
			lines.append(cells)
		_lines[dir] = lines


func _ranks(values: PackedInt64Array) -> PackedByteArray:
	var state := PackedByteArray()
	state.resize(values.size())
	for i in values.size():
		var v := values[i]
		var rank := 0
		while v > 1:
			v >>= 1
			rank += 1
		state[i] = rank
	return state


## Best value over the player's moves; a board with no move left is worth nothing.
func _max(state: PackedByteArray, depth: int, probability: float) -> float:
	var best := 0.0
	for dir: Board.Dir in ORDER:
		var moved := _move(state, dir)
		if moved == state:
			continue
		best = maxf(best, _chance(moved, depth, probability))
		if _timed_out:
			return 0.0
	return best


## Expected value over every spawn the game could make after a move.
func _chance(state: PackedByteArray, depth: int, probability: float) -> float:
	if depth <= 0 or probability < MIN_PROBABILITY:
		return _evaluate(state)
	if Time.get_ticks_usec() >= _deadline:
		_timed_out = true
		return 0.0
	var known = _memo.get(state)
	if known != null and known[0] >= depth:
		return known[1]
	var empty := PackedInt32Array()
	for i in state.size():
		if state[i] == 0:
			empty.append(i)
	if empty.is_empty():
		return _evaluate(state)
	var share := probability / empty.size()
	var total := 0.0
	for cell in empty:
		var two := state.duplicate()
		two[cell] = 1
		total += (1.0 - SPAWN_FOUR_CHANCE) * _max(two, depth - 1, share * (1.0 - SPAWN_FOUR_CHANCE))
		var four := state.duplicate()
		four[cell] = 2
		total += SPAWN_FOUR_CHANCE * _max(four, depth - 1, share * SPAWN_FOUR_CHANCE)
		if _timed_out:
			return 0.0
	var value := total / empty.size()
	_memo[state] = [depth, value]
	return value


## Slides and merges every line of [param state] towards [param dir]; returns a new state.
func _move(state: PackedByteArray, dir: Board.Dir) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(state.size())
	for cells: PackedInt32Array in _lines[dir]:
		var write := 0
		var last := 0
		for cell in cells:
			var rank := state[cell]
			if rank == 0:
				continue
			if rank == last:
				out[cells[write - 1]] = rank + 1
				last = 0
			else:
				out[cells[write]] = rank
				last = rank
				write += 1
	return out


func _evaluate(state: PackedByteArray) -> float:
	var total := 0.0
	for dir: Board.Dir in [Board.Dir.LEFT, Board.Dir.UP]:
		for cells: PackedInt32Array in _lines[dir]:
			var key := 0
			for cell in cells:
				key = (key << 6) | state[cell]
			var score = _line_scores.get(key)
			if score == null:
				score = _line_score(state, cells)
				_line_scores[key] = score
			total += score
	return total


func _line_score(state: PackedByteArray, cells: PackedInt32Array) -> float:
	var sum := 0.0
	var empty := 0
	var merges := 0
	var previous := 0
	var run := 0
	for cell in cells:
		var rank := state[cell]
		sum += pow(rank, SUM_POWER)
		if rank == 0:
			empty += 1
			continue
		if previous == rank:
			run += 1
		elif run > 0:
			merges += 1 + run
			run = 0
		previous = rank
	if run > 0:
		merges += 1 + run
	var falling := 0.0
	var rising := 0.0
	for i in range(1, cells.size()):
		var a := pow(state[cells[i - 1]], MONOTONICITY_POWER)
		var b := pow(state[cells[i]], MONOTONICITY_POWER)
		if a > b:
			falling += a - b
		else:
			rising += b - a
	return LOST_PENALTY + EMPTY_WEIGHT * empty + MERGES_WEIGHT * merges \
			- MONOTONICITY_WEIGHT * minf(falling, rising) - SUM_WEIGHT * sum
