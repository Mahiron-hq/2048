extends Node
## On-device measurement run, active only in the bench exports (feature tag "bench"; they keep
## their own save file, so a player's data is never touched). Steps through the phases in PHASES,
## printing "BENCH|begin|<name>" and "BENCH|end|<name>" for tools/device_bench.py, which samples the
## process's CPU time between the two; then times the hint engine on every level and board size.

const SETTLE := 4.0
## [name, seconds, settings]: show_fps, fps_limit, quality, screen, and moves per second (0: none).
const PHASES := [
	["idle-menu", 20.0, {"fps": false, "limit": 0, "quality": 2, "screen": "menu", "rate": 0.0}],
	["idle-game", 20.0, {"fps": false, "limit": 0, "quality": 2, "screen": "game", "rate": 0.0}],
	["redraw-cap-none", 20.0, {"fps": true, "limit": 0, "quality": 2, "screen": "game", "rate": 0.0}],
	["redraw-cap-120", 20.0, {"fps": true, "limit": 120, "quality": 2, "screen": "game", "rate": 0.0}],
	["redraw-cap-90", 20.0, {"fps": true, "limit": 90, "quality": 2, "screen": "game", "rate": 0.0}],
	["redraw-cap-60", 20.0, {"fps": true, "limit": 60, "quality": 2, "screen": "game", "rate": 0.0}],
	["redraw-cap-30", 20.0, {"fps": true, "limit": 30, "quality": 2, "screen": "game", "rate": 0.0}],
	["redraw-quality-medium", 20.0, {"fps": true, "limit": 0, "quality": 1, "screen": "game", "rate": 0.0}],
	["redraw-quality-low", 20.0, {"fps": true, "limit": 0, "quality": 0, "screen": "game", "rate": 0.0}],
	["play-2-moves-per-s", 20.0, {"fps": false, "limit": 0, "quality": 2, "screen": "game", "rate": 2.0}],
	["play-5-moves-per-s", 20.0, {"fps": false, "limit": 0, "quality": 2, "screen": "game", "rate": 5.0}],
]
## Long runs for the battery estimate: [name, seconds, settings].
const BATTERY := [
	["battery-play", 600.0, {"fps": false, "limit": 0, "quality": 2, "screen": "game", "rate": 0.55}],
	["battery-idle-game", 600.0, {"fps": false, "limit": 0, "quality": 2, "screen": "game", "rate": 0.0}],
]
## Positions per board size for the hint timings, and how many of them the 15-second level gets.
const HINT_POSITIONS := 8
const SMART_POSITIONS := 3

var app: App
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	app = get_parent()
	_rng.seed = 2048
	_run.call_deferred()


func _run() -> void:
	await _wait(3.0)
	app.sfx.music_enabled = true
	app.store.tutorial_games = SaveStore.TUTORIAL_GAMES
	print("BENCH|info|cores %d|refresh %d|native %s" % [OS.get_processor_count(),
			roundi(DisplayServer.screen_get_refresh_rate()), ClassDB.class_exists(&"HintEngine")])
	for phase in PHASES:
		await _phase(phase[0], phase[1], phase[2])
	await _hints()
	for phase in BATTERY:
		await _phase(phase[0], phase[1], phase[2])
	print("BENCH|done")


func _phase(phase_name: String, seconds: float, s: Dictionary) -> void:
	app.set_show_fps(s.fps)
	app.set_fps_limit(s.limit)
	app.set_quality(s.quality)
	if s.screen == "menu":
		app._to_menu()
	elif not app.is_current(app._game):
		app._start_new_game()
	await _wait(SETTLE)
	print("BENCH|begin|" + phase_name)
	var frames := Engine.get_frames_drawn()
	var started := Time.get_ticks_msec()
	var t := 0.0
	var next_move := 0.0
	while t < seconds:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		if s.rate > 0.0 and t >= next_move:
			next_move = t + 1.0 / s.rate
			_move()
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("BENCH|end|%s|frames %.1f/s" % [phase_name, (Engine.get_frames_drawn() - frames) / elapsed])


func _move() -> void:
	var g := app._game
	if not g.board.can_move():
		g.start_new(4, false)
	for i in 4:
		var dir := _rng.randi_range(0, 3)
		var probe := Board.new(1)
		probe.from_dict(g.board.to_dict())
		if probe.move(dir).moved:
			g.request_move(dir)
			return


## Times every level on positions from seeded games of each board size.
func _hints() -> void:
	var runner := HintRunner.new()
	for side in [3, 4, 5, 6]:
		var positions := _positions(side)
		for level in [SaveStore.HintLevel.SIMPLE, SaveStore.HintLevel.MEDIUM, SaveStore.HintLevel.SMART]:
			var count := SMART_POSITIONS if level == SaveStore.HintLevel.SMART else HINT_POSITIONS
			for i in mini(count, positions.size()):
				# In play a tap starts the hint and wakes the main loop; the bench has no finger.
				app._still = 0.0
				app._rest(false)
				runner.start(positions[i], side, level)
				var t0 := Time.get_ticks_usec()
				var answer := runner.poll()
				while answer == HintRunner.RUNNING:
					await get_tree().process_frame
					answer = runner.poll()
				var ms := (Time.get_ticks_usec() - t0) / 1000.0
				var engine: Object = runner._engine
				print("BENCH|hint|%d|%d|%.1f|%d|%d|%s|%d" % [side, level, ms, runner.depth(),
						engine.nodes() if engine else 0, engine.finish() if engine else "gdscript", answer])


## Board positions from a game played by the medium hint at a short budget, spread over its length.
func _positions(side: int) -> Array[PackedInt64Array]:
	var engine: Object = ClassDB.instantiate(&"HintEngine")
	var b := Board.new(side * 101, side)
	b.new_game(side)
	var seen: Array[PackedInt64Array] = []
	var moves := 0
	while b.can_move() and moves < 1500:
		engine.start_custom(b.values, side, SaveStore.HintLevel.MEDIUM, 5, 2)
		var dir: int = engine.poll()
		while dir == HintRunner.RUNNING:
			OS.delay_msec(1)
			dir = engine.poll()
		if dir < 0:
			break
		b.move(dir)
		moves += 1
		if moves % 60 == 0:
			seen.append(b.values.duplicate())
	var out: Array[PackedInt64Array] = []
	var step := maxf(1.0, seen.size() / float(HINT_POSITIONS))
	var i := 0.0
	while int(i) < seen.size() and out.size() < HINT_POSITIONS:
		out.append(seen[int(i)])
		i += step
	return out


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
