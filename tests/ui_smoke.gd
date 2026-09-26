extends SceneTree
## Headless end-to-end check of the app flow, driven through real input events:
## godot --headless --path . --script res://tests/ui_smoke.gd   (exit code = failures)

const SAVE := "user://smoke_save.json"

var _failed := 0


func _initialize() -> void:
	DirAccess.remove_absolute(SAVE)
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		print("ok   ", msg)
	else:
		_failed += 1
		printerr("FAIL ", msg)


func _run() -> void:
	var app := _spawn_app()
	await _frames(5)
	check(app._current == app._menu, "starts on menu")
	check(not app._menu._continue.visible, "no Continue without a saved game")

	app._menu._play.pressed.emit()
	await _wait(0.5)
	check(app._current == app._game, "New game opens the game screen")
	var board := app._game.board
	check(board.empty_count() == Board.CELL_COUNT - 2, "two opening tiles")

	var moved := false
	for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var before := board.move_count
		await _swipe(Vector2(360, 700), dir * 120.0)
		if board.move_count == before + 1:
			moved = true
			break
	check(moved, "a touch swipe performs a move")

	var count := board.move_count
	await _swipe(Vector2(360, 700), Vector2(6, 3))
	check(board.move_count == count, "a tap does not move")

	check(board.can_undo(), "undo available after a move")
	app._game._undo_btn.pressed.emit()
	await _wait(0.3)
	check(board.move_count == count - 1, "undo reverts the move")

	for i in 6:
		for dir in [Board.Dir.LEFT, Board.Dir.DOWN, Board.Dir.RIGHT, Board.Dir.UP]:
			app._game.request_move(dir)
	await _wait(0.5)
	var snapshot := board.values.duplicate()
	var score := board.score
	check(app.store.best_score == score, "best score tracks the running score")

	app._on_back()
	await _wait(0.5)
	check(app._current == app._menu, "back goes to menu")
	check(app._menu._continue.visible, "Continue offered for the saved game")

	app._open_settings()
	await _wait(0.3)
	app._settings._music.button_pressed = true
	app._settings._haptics.button_pressed = false
	app.set_theme_mode(SaveStore.ThemeMode.LIGHT)
	app.set_language("ru")
	await _wait(0.3)
	check(not Palette.current.dark and I18n.current == "ru", "theme and language apply immediately")
	app._on_back()
	await _wait(0.3)

	# Simulate process death: throw the app away and start a new one on the same save file.
	app.queue_free()
	await _frames(3)
	# Statics survive in-process; reset them as a fresh process would have them.
	I18n.current = "en"
	Palette.current = Palette.make(true)
	app = _spawn_app()
	await _frames(5)
	check(app.store.best_score == score, "best score survives restart")
	check(app.store.music_on and not app.store.haptics_on, "settings survive restart")
	check(app.store.theme == SaveStore.ThemeMode.LIGHT and app.store.language == "ru", "theme/language survive restart")
	check(app._menu._subtitle.text == I18n.STRINGS.ru.SUBTITLE, "labels use the saved language at startup")
	app._menu._continue.pressed.emit()
	await _wait(0.4)
	check(app._game.board.values == snapshot and app._game.board.score == score, "Continue restores the exact board")

	app._game._ask_new_game()
	await _wait(0.3)
	check(app.is_modal_open(), "New game asks for confirmation mid-game")
	app._confirm._yes.pressed.emit()
	await _wait(0.4)
	check(app._game.board.move_count == 0 and app._game.board.score == 0, "confirmed new game starts fresh")
	check(app.store.best_score == score, "best score kept after new game")

	var g := app._game
	g.board.from_dict({"size": 4, "values": [2, 4, 2, 4, 4, 2, 4, 2, 2, 4, 2, 4, 4, 2, 8, 8], "score": 10, "moves": 5})
	g.board.rng.seed = 1
	g._board_view.show_board(g.board)
	var before_over := g.board.values.duplicate()
	g.request_move(Board.Dir.LEFT)
	await _wait(1.5)
	if not g.board.can_move():
		check(g.is_modal_open(), "game-over screen appears when stuck")
		g._game_over._again.pressed.emit()
		await _wait(0.4)
		check(not g.is_modal_open() and g.board.move_count == 0, "Play again restarts")
	else:
		check(g.board.values != before_over, "move applied (spawn left a move open)")

	app.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(SAVE)
	print("\nui smoke: %d failed" % _failed)
	quit(_failed)


func _spawn_app() -> App:
	var app: App = load("res://scenes/main.tscn").instantiate()
	app.store = SaveStore.new(SAVE)
	root.add_child(app)
	return app


## Touch-drags by [param delta] (viewport units) in a few steps, as a finger would.
func _swipe(from: Vector2, delta: Vector2) -> void:
	var k := root.get_final_transform().get_scale()
	var start := from * k
	var t := InputEventScreenTouch.new()
	t.pressed = true
	t.position = start
	Input.parse_input_event(t)
	await process_frame
	for i in range(1, 5):
		var d := InputEventScreenDrag.new()
		d.position = start + delta * k * (i / 4.0)
		d.relative = delta * k / 4.0
		Input.parse_input_event(d)
		await process_frame
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.position = start + delta * k
	Input.parse_input_event(up)
	await _wait(0.3)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(sec: float) -> void:
	await create_timer(sec).timeout
