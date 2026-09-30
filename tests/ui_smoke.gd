extends SceneTree
## Headless end-to-end check of the app flow, driven through real input events:
## godot --headless --path . --script res://tests/ui_smoke.gd   (exit code = failures)

const SAVE := "user://smoke_save.json"

var _failed := 0


func _initialize() -> void:
	DirAccess.remove_absolute(SAVE)
	# UI_SMOKE_FONT=<path to .ttf> lays everything out with that font instead of the bundled one,
	# e.g. DejaVu Sans, a much wider face, to prove the layouts tolerate it.
	var font_path := OS.get_environment("UI_SMOKE_FONT")
	if not font_path.is_empty():
		var file := FontFile.new()
		if file.load_dynamic_font(font_path) == OK:
			Fonts.override_font = file
			print("using font ", font_path)
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
	await _drag(slider, 0.02, _step_fraction(slider, 3))
	check(app.store.sound_volume == 3, "dragging the sound slider picks step 3 (got %d)" % app.store.sound_volume)
	var sfx_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Sfx.SFX_BUS))
	check(is_equal_approx(sfx_db, Sfx.level_db(3)), "effects bus follows the slider (%.1f dB)" % sfx_db)
	var music_slider: StepSlider = app._settings._music_volume
	await _drag(music_slider, 0.98, 0.98)
	await _wait(0.4)
	var music_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Sfx.MUSIC_BUS))
	check(app.store.music_volume == Sfx.LEVEL_COUNT and is_equal_approx(music_db, 0.0), "music slider reaches the top step (%.1f dB)" % music_db)
	await _gesture(music_slider, Vector2(music_slider.size.x * 0.1, music_slider.size.y * 0.5), Vector2(4, 220))
	await _wait(0.3)
	check(app.store.music_volume == Sfx.LEVEL_COUNT, "a vertical swipe that starts on a slider scrolls instead of moving it (%d)" % app.store.music_volume)
	var caps: Segmented = app._settings._fps_limit
	var limits: Array[int] = app._settings._fps_limits
	check(limits.slice(0, 2) == [30, 60] and limits[-1] == 0 and caps.options.size() == limits.size(), "FPS caps offered: %s" % [limits])
	var scroll: ScrollContainer = app._settings.find_children("*", "ScrollContainer", true, false)[0]
	scroll.ensure_control_visible(caps)
	await _frames(2)
	await _drag(caps, 1.5 / limits.size(), 1.5 / limits.size())
	await _wait(0.3)
	check(app.store.fps_limit == 60 and Engine.max_fps == 60, "tapping 60 caps the frame rate (%d, max_fps %d)" % [app.store.fps_limit, Engine.max_fps])
	await _drag(caps, 1.0 - 0.5 / limits.size(), 1.0 - 0.5 / limits.size())
	await _wait(0.3)
	check(app.store.fps_limit == 0 and Engine.max_fps == 0, "tapping ∞ lifts the cap (%d, max_fps %d)" % [app.store.fps_limit, Engine.max_fps])
	await _drag(caps, 0.5 / limits.size(), 1.0 - 0.5 / limits.size())
	await _wait(0.3)
	check(app.store.fps_limit == 0, "a drag that starts on the selector is a scroll, not a choice (%d)" % app.store.fps_limit)
	# A swipe scrolls the page wherever it starts: on a card's text, on a selector or on a switch.
	var theme_label: Control = app._settings.find_children("*", "SkinLabel", true, false).filter(
			func(l: SkinLabel) -> bool: return l.key == "THEME")[0]
	var before := {"theme": app.store.theme, "fps": app.store.show_fps, "lang": app.store.language}
	for start: Control in [theme_label, app._settings._language, app._settings._fps]:
		scroll.scroll_vertical = 0
		await _frames(3)
		var at := start.size * 0.5
		await _gesture(start, at, Vector2(0, -260))
		await _wait(0.2)
		check(scroll.scroll_vertical > 100, "a swipe that starts on %s scrolls the settings (%d)" % [start.get_class(), scroll.scroll_vertical])
	var after := {"theme": app.store.theme, "fps": app.store.show_fps, "lang": app.store.language}
	check(before == after, "scrolling changes no setting: %s -> %s" % [before, after])
	scroll.scroll_vertical = 0
	for i in 6:
		app.set_theme_mode(SaveStore.ThemeMode.LIGHT if i % 2 == 0 else SaveStore.ThemeMode.DARK)
		await _frames(2)
	var fades := app.get_children().filter(func(c: Node) -> bool: return c is TextureRect)
	check(fades.size() <= 1, "rapid theme switches keep a single crossfade (%d)" % fades.size())
	for fade: TextureRect in fades:
		check(fade.size.is_equal_approx(app.size), "theme crossfade matches the screen (%s vs %s)" % [fade.size, app.size])
	app.set_theme_mode(SaveStore.ThemeMode.LIGHT)
	app.set_language("ru")
	await _wait(0.5)
	check(not app.get_children().any(func(c: Node) -> bool: return c is TextureRect), "crossfade snapshot is gone after the fade")
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
	check(app.store.sound_volume == 3 and app.store.music_volume == Sfx.LEVEL_COUNT, "volume steps survive restart")
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
	await _fixes_121(app)
	await _hints(app)
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


func _fixes_121(app: App) -> void:
	var g := app._game

	# The swipe hint keeps pulsing until the first move and covers the whole board.
	g.start_new(4, false)
	await _wait(2.5)
	var hint: SwipeHint = g._board_view._hint
	check(hint.is_showing() and hint._pulse_tween != null and hint._pulse_tween.is_running(), "hint arrows keep pulsing")
	check(hint.board_rect == g._board_view.board_rect, "hint veil covers the whole board")

	# Swipes that start on the header/buttons are ignored; on the board they move.
	var header_point := g._header.get_global_rect().get_center()
	await _swipe(header_point, Vector2(0, 160))
	check(g.board.move_count == 0, "a swipe starting on the header does not move")
	var moved := false
	for d in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		await _swipe(g._board_view.get_global_rect().get_center(), d * 140.0)
		if g.board.move_count > 0:
			moved = true
			break
	check(moved, "a swipe starting on the board moves")

	# Statistics: move, undo, move counts one move.
	var before: int = app.store.stats_for(0).moves
	g.undo()
	await _frames(2)
	var guard := 0
	while g.board.move_count == 0 and guard < 4:
		g.request_move(guard)
		guard += 1
	check(app.store.stats_for(0).moves == before, "an undone move does not stay in the move count")

	# The size picker keeps its size when reopened.
	app._to_menu()
	await _wait(0.5)
	var heights := []
	for i in 3:
		app._menu._size.pressed.emit()
		await _wait(0.3)
		heights.append(app._picker._card.size.y)
		app._picker.close()
		await _wait(0.2)
	var rows_height: float = SizePicker.ROW_HEIGHT * 4
	check(heights[0] == heights[1] and heights[1] == heights[2] and heights[0] < rows_height * 1.4, "size picker stays four rows tall when reopened (%s)" % [heights])

	# Background saving: the latest state reaches the disk.
	app.save_now()
	app._wait_for_save()
	var probe := SaveStore.new(SAVE)
	check(probe.load_from_disk() and probe.best_for(4) == app.store.best_for(4), "background save writes the latest state")


func _board_rect(g: GameScreen) -> Rect2:
	return Rect2(g._board_view.global_position + g._board_view.board_rect.position, g._board_view.board_rect.size)


## Landscape game screen invariants: the board is large, visible and clear of every control,
## the controls are on screen and apart, and the board is centered unless all controls share one side.
func _hints(app: App) -> void:
	var g := app._game
	app._game.start_new(4, false)
	app._show_screen(g)
	await _wait(0.5)
	var menu := g._menu_btn.get_global_rect()
	var hint := g._hint_btn.get_global_rect()
	check(app.store.hints_on and g._hint_btn.visible, "the hint button is shown by default")
	check(hint.position.x > menu.end.x and hint.position.x - menu.end.x < 30.0 and absf(hint.get_center().y - menu.get_center().y) < 2.0,
			"portrait: hint button right next to the menu (%s vs %s)" % [hint, menu])
	var values := g.board.values.duplicate()
	g._hint_btn.pressed.emit()
	check(g.is_hint_busy(), "pressing the bulb starts thinking")
	for i in 120:
		if not g.is_hint_busy():
			break
		await _frames(1)
	await _frames(2)
	check(g._board_view.is_showing_move_hint(), "the suggestion plays on the board")
	check(g.board.values == values, "a hint never makes the move itself")
	var leaned := false
	for i in 30:
		await _frames(1)
		leaned = leaned or g._board_view._layer.position.length() > 1.0
	check(leaned, "the tiles lean towards the suggested move")
	await _wait(1.6)
	check(not g._board_view.is_showing_move_hint() and g._board_view._layer.position == Vector2.ZERO, "the hint ends with every tile back in place")
	g._idle = GameScreen.HINT_IDLE - 0.05
	await _wait(0.4)
	check(g._hint_btn.glow > 0.0, "the bulb lights up after %d idle seconds" % GameScreen.HINT_IDLE)
	for dir in [Board.Dir.LEFT, Board.Dir.RIGHT, Board.Dir.UP, Board.Dir.DOWN]:
		g.request_move(dir)
	await _frames(2)
	check(g._hint_btn.glow == 0.0 and g._idle < 1.0, "a move puts the bulb out and restarts the idle clock")
	app.set_hints(false)
	await _frames(2)
	check(not g._hint_btn.visible and not app.store.hints_on, "turning hints off in settings hides the button")
	g.request_hint()
	check(not g.is_hint_busy(), "no hint is computed while hints are off")
	app.set_hints(true)
	await _frames(2)
	check(g._hint_btn.visible, "turning hints back on shows the button")


func _check_landscape_game(g: GameScreen, vp: Rect2, tag: String) -> void:
	var board_rect := _board_rect(g)
	check(_inside(board_rect, vp) and board_rect.size.x > vp.size.y * 0.6, "%s: board is large and fully visible (%s)" % [tag, board_rect])
	var controls: Array[Control] = [g._logo, g._menu_btn, g._score_box, g._best_box, g._hint_btn, g._undo_btn, g._new_btn]
	for i in controls.size():
		var r := controls[i].get_global_rect()
		check(_inside(r, vp), "%s: %s is on screen (%s)" % [tag, controls[i].get_class(), r])
		check(not r.intersects(board_rect), "%s: %s stays off the board" % [tag, controls[i].get_class()])
		for j in range(i + 1, controls.size()):
			check(not r.intersects(controls[j].get_global_rect()), "%s: controls %d and %d do not overlap" % [tag, i, j])
	if g._arrangement != GameScreen.Arrangement.ONE_SIDE:
		var center := g.get_global_rect().get_center().x
		check(absf(board_rect.get_center().x - center) < 1.5, "%s: board centered on screen (%.0f vs %.0f)" % [tag, board_rect.get_center().x, center])
	check(_view_matches(g), "%s: tiles follow the resized board" % tag)
	var hint := g._hint_btn.get_global_rect()
	var best := g._best_box.get_global_rect()
	check(g._hint_btn.visible and hint.position.x >= best.end.x and hint.position.x - best.end.x < 30.0 			and hint.get_center().y > best.position.y and hint.get_center().y < best.end.y,
			"%s: hint button right of the best score (%s vs %s)" % [tag, hint, best])
	await _frames(1)


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
	var board_rect := _board_rect(g)
	await _check_landscape_game(g, vp, "16:9")
	root.size = Vector2i(2400, 1080)
	await _frames(8)
	await _wait(0.3)
	vp = root.get_visible_rect()
	await _check_landscape_game(g, vp, "20:9")
	check(g._arrangement == GameScreen.Arrangement.ROW, "20:9 keeps logo, menu and score in one line")
	board_rect = _board_rect(g)
	var logo := g._logo.get_global_rect()
	var menu := g._menu_btn.get_global_rect()
	var score := g._score_box.get_global_rect()
	var best := g._best_box.get_global_rect()
	var undo := g._undo_btn.get_global_rect()
	var new_game := g._new_btn.get_global_rect()
	var area := g.get_global_rect()
	check(absf(logo.position.x - area.position.x) < 1.0 and absf(logo.position.y - board_rect.position.y) < 1.0, "logo sits in the top-left corner")
	check(menu.position.x > logo.end.x and menu.position.x - logo.end.x < 20.0 and menu.end.y < logo.end.y, "menu button right next to the logo")
	check(score.position.x - menu.end.x >= GameScreen.BRAND_GAP - 1.0 and absf(score.position.y - board_rect.position.y) < 1.0, "score after a gap, level with the board top")
	check(absf(board_rect.position.x - score.end.x - GameScreen.BOARD_GAP) < 1.5, "score nearly touches the board's left edge")
	check(absf(best.position.x - board_rect.end.x - GameScreen.BOARD_GAP) < 1.5 and absf(best.position.y - board_rect.position.y) < 1.0, "best nearly touches the board's right edge, at the top")
	check(absf(undo.position.x - area.position.x) < 1.0 and absf(maxf(undo.end.y, new_game.end.y) - board_rect.end.y) < 1.0, "undo and new game in the bottom-left corner")
	if g._side_actions.columns == 2:
		check(new_game.position.x > undo.end.x and absf(new_game.position.y - undo.position.y) < 1.0, "undo and new game side by side")
	else:
		check(new_game.position.y > undo.end.y and absf(new_game.position.x - undo.position.x) < 1.0, "wide labels stack undo over new game")
	var moves_before := g.board.move_count
	await _swipe(Vector2((menu.end.x + score.position.x) * 0.5, menu.get_center().y), Vector2(0, 150))
	check(g.board.move_count == moves_before, "a swipe starting in the top band beside the board does not move")
	await _swipe(score.get_center(), Vector2(0, 150))
	check(g.board.move_count == moves_before, "a swipe starting on the score does not move")
	await _swipe(undo.get_center(), Vector2(0, -150))
	check(g.board.move_count == moves_before, "a swipe starting on the buttons does not move")
	# Narrower and near-square landscape screens stack the controls instead of shrinking the board.
	for px: Vector2i in [Vector2i(2048, 1536), Vector2i(1242, 1080)]:
		root.size = px
		await _frames(8)
		await _wait(0.3)
		vp = root.get_visible_rect()
		await _check_landscape_game(g, vp, "%dx%d" % [px.x, px.y])
		check(g._arrangement != GameScreen.Arrangement.ROW, "%dx%d stacks the controls (%d)" % [px.x, px.y, g._arrangement])
	check(g._arrangement == GameScreen.Arrangement.ONE_SIDE, "a near-square screen keeps every control on one side")
	root.size = Vector2i(2400, 1080)
	await _frames(8)
	await _wait(0.3)
	vp = root.get_visible_rect()
	app._to_menu()
	await _wait(0.5)
	app._menu._size.pressed.emit()
	await _wait(0.4)
	var card := app._picker._card
	var card_rect := Rect2(card.global_position, card.size * card.scale)
	check(_inside(card_rect, vp), "size picker stays on screen in landscape (%s in %s)" % [card_rect, vp])
	app._picker.close()
	await _wait(0.2)
	app._menu._continue.pressed.emit()
	await _wait(0.5)
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


## Fraction of the slider width where [param step] sits.
func _step_fraction(slider: StepSlider, step: int) -> float:
	var usable := slider.size.x - StepSlider.KNOB_RADIUS * 2.0
	return (StepSlider.KNOB_RADIUS + usable * (step - 1) / float(slider.steps - 1)) / slider.size.x


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


## Presses [param c] at local [param at], moves the pointer by [param delta] and releases, via
## real events.
func _gesture(c: Control, at: Vector2, delta: Vector2) -> void:
	var k := root.get_final_transform().get_scale()
	var start := c.get_global_rect().position + at
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = start * k
	Input.parse_input_event(down)
	await process_frame
	for i in 4:
		var move := InputEventMouseMotion.new()
		move.position = (start + delta * (i + 1) / 4.0) * k
		# ScrollContainer scrolls by the reported relative motion, not by position.
		move.relative = delta / 4.0 * k
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(move)
		await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = (start + delta) * k
	Input.parse_input_event(up)
	await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(sec: float) -> void:
	await create_timer(sec).timeout
