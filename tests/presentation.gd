extends SceneTree
## Scripted ~18 s tour for the proof video:
## godot --path . --write-movie screenshots/result/frame.png --fixed-fps 30 --quit-after 560 --script res://tests/presentation.gd

const SAVE := "user://presentation_save.json"

var app: App


func _initialize() -> void:
	DirAccess.remove_absolute(SAVE)
	app = load("res://scenes/main.tscn").instantiate()
	app.store = SaveStore.new(SAVE)
	root.add_child(app)
	app.set_language("ru")
	app.set_theme_mode(SaveStore.ThemeMode.DARK)
	_run.call_deferred()


func _run() -> void:
	await _wait(1.6)
	app._start_new_game()
	app._game.board.rng.seed = 2024
	await _wait(0.7)
	var dirs := [Board.Dir.LEFT, Board.Dir.DOWN, Board.Dir.RIGHT, Board.Dir.DOWN, Board.Dir.LEFT, Board.Dir.DOWN]
	for i in 14:
		_move(_best_dir(dirs))
		await _wait(0.28)

	_load([[64, 64, 32, 4], [16, 16, 8, 2], [4, 2, 0, 0], [2, 0, 0, 0]], 1840)
	await _wait(0.6)
	_move(Board.Dir.LEFT)
	await _wait(2.2)
	_move(Board.Dir.UP)
	await _wait(0.4)
	app._game.undo()
	await _wait(0.8)

	app._open_settings()
	await _wait(0.9)
	app._settings._theme.set_index_silently(0)
	app.set_theme_mode(SaveStore.ThemeMode.LIGHT)
	await _wait(1.0)
	app._close_settings()
	await _wait(0.7)
	for i in 6:
		_move(_best_dir(dirs))
		await _wait(0.28)

	_load([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 8], [4, 2, 16, 16]], 7236)
	await _wait(0.5)
	_move(Board.Dir.LEFT)
	await _wait(3.0)
	quit(0)


## Greedy pick: the direction that merges the most value, preferring the given cycle order.
func _best_dir(order: Array) -> Board.Dir:
	var best: Board.Dir = order[0]
	var best_gain := -1
	for d in order:
		var probe := Board.new(1)
		probe.from_dict(app._game.board.to_dict())
		var r := probe.move(d)
		if r.moved and r.gained > best_gain:
			best_gain = r.gained
			best = d
	return best


func _move(d: Board.Dir) -> void:
	app._game.request_move(d)


func _load(rows: Array, score: int) -> void:
	var flat := []
	for r in rows:
		flat.append_array(r)
	var g := app._game
	g.board.from_dict({"size": 4, "values": flat, "score": score, "moves": 60})
	g._pending_over = false
	g._board_view.show_board(g.board, BoardView.Appear.FADE)
	g._refresh_scores(false)


func _wait(sec: float) -> void:
	await create_timer(sec).timeout
