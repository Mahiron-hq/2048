extends SceneTree
## Long-game stress run: plays thousands of 6x6 moves through the real game screen and reports
## per-move and per-frame main-thread cost, to catch spikes or costs that grow as a game goes on.
## godot --headless --path . --script res://tests/perf_probe.gd

const SAVE := "user://perf_probe.json"
const MOVES := 4000

var app: App


func _initialize() -> void:
	DirAccess.remove_absolute(SAVE)
	_run.call_deferred()


func _run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.store = SaveStore.new(SAVE)
	root.add_child(app)
	await process_frame
	app.sfx.music_enabled = false
	app.set_undo_limit(5)
	app.selected_size = 6
	app._start_new_game()
	await process_frame
	var g := app._game
	var rng := RandomNumberGenerator.new()
	rng.seed = 2048
	var move_us := PackedInt64Array()
	var frame_us := PackedInt64Array()
	var games := 1
	var top_score := 0
	for i in MOVES:
		if not g.board.can_move() or g.is_modal_open():
			g.close_overlays()
			g.start_new(6, false)
			games += 1
		var t0 := Time.get_ticks_usec()
		g.request_move(rng.randi_range(0, 3) as Board.Dir)
		if i % 7 == 0:
			g.undo()
		move_us.append(Time.get_ticks_usec() - t0)
		top_score = maxi(top_score, g.board.score)
		for f in 2:
			var f0 := Time.get_ticks_usec()
			await process_frame
			frame_us.append(Time.get_ticks_usec() - f0)
	_report("move", move_us)
	_report("frame", frame_us)
	var q := move_us.size() / 4
	print("move avg first quarter %.3f ms, last quarter %.3f ms" % [_avg(move_us.slice(0, q)), _avg(move_us.slice(move_us.size() - q))])
	print("games %d, top score %d, best tile %d" % [games, top_score, app.store.stats_for(6).best_tile])
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE)
	quit(0)


func _report(label: String, samples: PackedInt64Array) -> void:
	var sorted := Array(samples)
	sorted.sort()
	var n := sorted.size()
	print("%s: n=%d avg %.3f ms, p99 %.3f ms, max %.3f ms" % [label, n, _avg(samples), sorted[int(n * 0.99)] / 1000.0, sorted[n - 1] / 1000.0])


func _avg(samples: PackedInt64Array) -> float:
	var total := 0
	for v in samples:
		total += v
	return total / 1000.0 / maxi(samples.size(), 1)
