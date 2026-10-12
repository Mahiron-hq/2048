class_name HintRunner
extends RefCounted
## Runs one move-hint search at a time in the background. Uses the native HintEngine (Rust,
## several threads) and falls back to the GDScript [HintSolver] on one worker thread when the
## native library is missing on this platform.

## [method poll] while the search is still running.
const RUNNING := -2
## [method poll] when no move changes the board.
const NO_MOVE := -1
## Thinking time of the GDScript fallback per [enum SaveStore.HintLevel].
const FALLBACK_BUDGET_MS: Array[int] = [40, 1000, 3000]

var _engine: Object = null
var _solver := HintSolver.new()
## Fallback search in flight (WorkerThreadPool task id), or -1.
var _task := -1
## Written by the fallback task; read once it has completed.
var _result := NO_MOVE
var _started_ms := 0
var _budget_ms := 1


func _init() -> void:
	if ClassDB.class_exists(&"HintEngine"):
		_engine = ClassDB.instantiate(&"HintEngine")


func is_native() -> bool:
	return _engine != null


## Starts a search of [param values] on a [param size] board at [param level], replacing any
## search still running. Returns false when nothing could be started.
func start(values: PackedInt64Array, size: int, level: SaveStore.HintLevel) -> bool:
	cancel()
	_started_ms = Time.get_ticks_msec()
	_budget_ms = FALLBACK_BUDGET_MS[level]
	if _engine:
		return _engine.start(values, size, level)
	_wait_fallback()
	_result = RUNNING
	var copy := values.duplicate()
	var budget := _budget_ms
	_task = WorkerThreadPool.add_task(func() -> void:
		_result = _solver.best_move(copy, size, budget), false, "move hint")
	return true


## RUNNING while the search runs, then a [enum Board.Dir] or NO_MOVE.
func poll() -> int:
	if _engine:
		return _engine.poll()
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return RUNNING
		_wait_fallback()
	return _result


func is_running() -> bool:
	return poll() == RUNNING


## Stops the running search; its answer is dropped by the caller.
func cancel() -> void:
	if _engine:
		_engine.cancel()
	# The GDScript solver cannot be interrupted; its answer is simply ignored.


## Share of the time budget used, 0 to 1.
func progress() -> float:
	if _engine:
		return _engine.progress()
	if _task < 0:
		return 1.0
	return clampf(float(Time.get_ticks_msec() - _started_ms) / _budget_ms, 0.0, 0.99)


## Milliseconds since the running (or last) search started.
func elapsed_ms() -> int:
	return Time.get_ticks_msec() - _started_ms


## Deepest finished search depth of the running or last search.
func depth() -> int:
	return _engine.depth() if _engine else _solver.last_depth


## Waits for the fallback search, if any; call before the runner goes away.
func finish() -> void:
	if _engine:
		_engine.cancel()
		while _engine.poll() == RUNNING:
			OS.delay_msec(1)
	_wait_fallback()


func _wait_fallback() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
