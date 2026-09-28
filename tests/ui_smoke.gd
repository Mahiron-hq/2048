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
	check(board.size == 4 and board.empty_count() == board.cell_count - 2, "a 4x4 game with two opening tiles by default")

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

	var consistent := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 60:
		if not board.can_move():
			app._game.start_new(false)
		app._game.request_move(rng.randi_range(0, 3))
		if i % 3 == 0:
			await _frames(2)
		app._game.undo()
		if i % 2 == 0:
			await _frames(3)
		if not _view_matches(app._game):
			consistent = false
			break
		app._game.request_move(rng.randi_range(0, 3))
	check(consistent, "undo animation leaves the view identical to the board")

	for i in 6:
		for dir in [Board.Dir.LEFT, Board.Dir.DOWN, Board.Dir.RIGHT, Board.Dir.UP]:
			app._game.request_move(dir)
	await _wait(0.5)
	var snapshot := board.values.duplicate()
	var score := board.score
	check(app.store.best_for(4) == score, "best score tracks the running score")

	app._on_back()
	await _wait(0.5)
	check(app._current == app._menu, "back goes to menu")
	check(app._menu._continue.visible, "Continue offered for the saved game")

	app._open_settings()
	await _wait(0.3)
	var sfx := app.sfx
	check(sfx.music_enabled and sfx._music.playing, "music is on by default")
	app._settings._music.button_pressed = false
	await _wait(0.5)
	var mid_out := sfx.music_level()
	await _wait(1.3)
	check(mid_out > 0.05 and mid_out < 0.95, "music fades out gradually (level %.2f mid-fade)" % mid_out)
	check(sfx.music_level() == 0.0 and sfx._music.stream_paused, "music is paused once faded out")
	var paused_at := sfx._music.get_playback_position()
	app._settings._music.button_pressed = true
	await _wait(0.8)
	var mid_in := sfx.music_level()
	check(mid_in > 0.05 and mid_in < 0.95, "music fades in gradually (level %.2f mid-fade)" % mid_in)
	check(sfx._music.get_playback_position() >= paused_at, "music resumes where it paused")
	await _wait(1.8)
	check(is_equal_approx(sfx.music_level(), 1.0), "music reaches full level")
	app._settings._haptics.button_pressed = false
	var slider: StepSlider = app._settings._sound_volume
	await _drag(slider, 0.02, 0.26)
	check(app.store.sound_volume == 2, "dragging the sound slider picks step 2 (got %d)" % app.store.sound_volume)
	var sfx_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Sfx.SFX_BUS))
	check(is_equal_approx(sfx_db, Sfx.level_db(2)), "effects bus follows the slider (%.1f dB)" % sfx_db)
	var music_slider: StepSlider = app._settings._music_volume
	await _drag(music_slider, 0.98, 0.98)
	await _wait(0.4)
	var music_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Sfx.MUSIC_BUS))
	check(app.store.music_volume == 5 and is_equal_approx(music_db, Sfx.level_db(5)), "music slider sets step 5 (%.1f dB)" % music_db)
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
	check(app.store.best_for(4) == score, "best score survives restart")
	check(app.store.music_on and not app.store.haptics_on, "settings survive restart")
	check(app.store.sound_volume == 2 and app.store.music_volume == 5, "volume steps survive restart")
	check(app.sfx._music.playing, "music starts on launch when enabled")
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
	check(app.store.best_for(4) == score, "best score kept after new game")

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

	await _new_features(app)
	await _landscape(app)

	app.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(SAVE)
	print("\nui smoke: %d failed" % _failed)
	quit(_failed)


func _new_features(app: App) -> void:
	var g := app._game

	# Swipe hint: shown when a game starts, gone with the first move.
	g.start_new(0, false)
	await _wait(0.4)
	check(g._board_view.is_hint_visible(), "swipe hint shows at the start of a game")
	for dir in [Board.Dir.LEFT, Board.Dir.RIGHT, Board.Dir.UP, Board.Dir.DOWN]:
		g.request_move(dir)
		if g.board.move_count > 0:
			break
	await _wait(0.5)
	check(not g._board_view.is_hint_visible(), "swipe hint fades after the first move")
	await _swipe(Vector2(360, 700), Vector2(0, 0))
	check(not g._board_view.is_hint_visible(), "swipe hint stays hidden for the rest of the game")

	# Undo depth: three steps back to the very start, and not one further.
	app.set_undo_limit(3)
	g.start_new(0, false)
	var start_values := g.board.values.duplicate()
	var guard := 0
	while g.board.move_count < 3 and guard < 40:
		g.request_move(guard % 4)
		guard += 1
		await _frames(1)
	check(g._undo_btn.visible and g._undo_btn.badge == 3, "undo shows three available steps (badge %d)" % g._undo_btn.badge)
	for i in 3:
		g._undo_btn.pressed.emit()
		await _frames(2)
	await _wait(0.3)
	check(g.board.values == start_values and g.board.move_count == 0, "three undos return to the start of the game")
	check(g._undo_btn.disabled and _view_matches(g), "undo is spent and the view matches the board")
	g._undo_btn.pressed.emit()
	await _frames(2)
	check(g.board.values == start_values, "extra undo presses do nothing")
	app.set_undo_limit(0)
	check(not g._undo_btn.visible, "undo button hides when undo is off")
	app.set_undo_limit(1)

	# Statistics: replacing a game after a move counts it as played.
	var played: int = app.store.stats_for(0).games
	guard = 0
	while g.board.move_count == 0 and guard < 4:
		g.request_move(guard)
		guard += 1
	g.start_new(0, false)
	check(app.store.stats_for(0).games == played + 1, "an abandoned game counts as played")

	# Board size from the menu: picker, 5x5 game.
	app._to_menu()
	await _wait(0.5)
	check(app._menu._size.text_override == "4×4", "menu defaults to 4×4")
	app._menu._size.pressed.emit()
	await _wait(0.3)
	check(app._picker.is_open and app._picker._list.get_child_count() == 4, "size button opens a picker with four sizes")
	var five: BaseButton = app._picker._list.get_child(2)
	five.pressed.emit()
	await _wait(0.3)
	check(not app._picker.is_open and app.selected_size == 5 and app._menu._size.text_override == "5×5", "picking 5×5 updates the menu")
	app._menu._play.pressed.emit()
	await _wait(0.3)
	if app._confirm.is_open:
		app._confirm._yes.pressed.emit()
	await _wait(0.6)
	check(app._current == g and g.board.size == 5 and g._board_view.grid_size == 5, "a 5×5 game starts")
	check(_view_matches(g), "5×5 view matches the board")
	var moved := false
	for dir in [Board.Dir.LEFT, Board.Dir.RIGHT, Board.Dir.UP, Board.Dir.DOWN]:
		g.request_move(dir)
		if g.board.move_count > 0:
			moved = true
			break
	await _wait(0.4)
	check(moved and _view_matches(g), "5×5 moves animate into place")
	check(app.store.best_for(5) == g.board.score, "records are tracked for 5×5")

	# Statistics screen.
	app._to_menu()
	await _wait(0.4)
	app._menu._stats.pressed.emit()
	await _wait(0.5)
	var st := app.store.stats_for(0)
	check(app._current == app._stats, "Statistics opens from the menu")
	check(app._stats._cards.GAMES_PLAYED._value.text == I18n.number(st.games) and st.moves > 0, "statistics show games and moves")
	app._on_back()
	await _wait(0.4)
	check(app._current == app._menu, "back returns from statistics")


func _landscape(app: App) -> void:
	var original := root.size
	root.size = Vector2i(1600, 900)
	await _frames(6)
	var vp := root.get_visible_rect()
	check(vp.size.x > vp.size.y, "viewport turns landscape (%s)" % [vp.size])
	await _wait(0.4)
	check(app._menu._landscape_mode, "menu switches to its two-column layout")
	check(_inside(app._menu._buttons.get_global_rect(), vp) and _inside(app._menu._best_card.get_global_rect(), vp), "menu content fits the landscape screen")
	app._menu._continue.pressed.emit()
	await _wait(0.6)
	var g := app._game
	check(g._landscape_mode, "game switches to the side-panel layout")
	var board_rect := Rect2(g._board_view.global_position + g._board_view.board_rect.position, g._board_view.board_rect.size)
	check(_inside(board_rect, vp) and board_rect.size.x > vp.size.y * 0.6, "board is large and fully visible (%s)" % [board_rect])
	check(not board_rect.intersects(g._side.get_global_rect()), "side panel does not overlap the board")
	for b in [g._menu_btn, g._new_btn, g._score_box, g._best_box]:
		check(_inside(b.get_global_rect(), vp), "%s is on screen" % b.get_class())
	check(_view_matches(g), "tiles follow the resized board")
	app._open_settings()
	await _wait(0.5)
	check(_inside(app._settings._undo.get_global_rect(), vp) or app._settings._undo.get_global_rect().position.y > vp.size.y * 0.5, "settings stay laid out in landscape")
	app._close_settings()
	await _wait(0.4)
	root.size = original
	await _frames(6)
	check(not g._landscape_mode, "back to portrait layout")


func _inside(r: Rect2, area: Rect2) -> bool:
	return area.grow(1.0).encloses(r)


func _view_matches(g: GameScreen) -> bool:
	var view := g._board_view
	view.complete_animations()
	var shown := 0
	for c in view._layer.get_children():
		if c.visible:
			shown += 1
	var expected := 0
	for i in g.board.cell_count:
		if g.board.values[i] == 0:
			continue
		expected += 1
		var t: TileView = view._tiles.get(g.board.ids[i])
		if t == null or not t.visible or t.value != g.board.values[i] or t.position != view.cell_position(i) or t.scale != Vector2.ONE:
			printerr("view mismatch at cell %d" % i)
			return false
	return shown == expected


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


## Presses the slider at fraction [param a] of its width and drags to [param b], via real events.
func _drag(slider: Control, a: float, b: float) -> void:
	var r := slider.get_global_rect()
	var k := root.get_final_transform().get_scale()
	var y := r.get_center().y
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(r.position.x + r.size.x * a, y) * k
	Input.parse_input_event(down)
	await process_frame
	var move := InputEventMouseMotion.new()
	move.position = Vector2(r.position.x + r.size.x * b, y) * k
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(move)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = move.position
	Input.parse_input_event(up)
	await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(sec: float) -> void:
	await create_timer(sec).timeout
