extends SceneTree
## Store and README screenshots from real games. The hint engine plays a few games with fixed
## seeds first; every screen then replays those moves, so each score, move count, record and
## statistic is one the game really reached. Needs a GPU window and the native hint engine:
## godot --path . --script res://tools/make_screenshots.gd
## Writes store/screenshots/{ru,en}/01..06-*.png (1080x1920) and docs/screenshots/*.png.

const SAVE := "user://screenshots_save.json"
## Thinking time per move while the games are played; the medium level at this budget plays well
## enough to reach 2048 and beyond.
const MOVE_BUDGET_MS := 15
## Statistics show this much play time per move, a calm human pace; the bot itself is faster.
const SECONDS_PER_MOVE := 1.8

## [seed, side, stop]: stop is "loss", or a tile value to play up to.
const GAMES := {
	"first": [2026, 4, "loss"],
	"main": [1103, 4, "loss"],
	"big": [9, 6, 4096],
}

var _moves := {}
var app: App
var _vp: SubViewport


func _initialize() -> void:
	OS.low_processor_usage_mode = false
	for dir in ["store/screenshots/ru", "store/screenshots/en", "docs/screenshots"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + dir))
	_run.call_deferred()


func _run() -> void:
	if not ClassDB.class_exists(&"HintEngine"):
		push_error("the native hint engine is needed: python tools/build_native.py host")
		quit(1)
		return
	for name in GAMES:
		_moves[name] = _play(GAMES[name][0], GAMES[name][1], GAMES[name][2])
		print("%s: %d moves" % [name, _moves[name].size()])
	for lang in ["ru", "en"]:
		await _store(lang)
	await _docs_tall()
	await _docs_game()
	await _docs_landscape()
	await _docs_tablet()
	quit(0)


## Plays a game with the hint engine and returns its directions.
func _play(seed_value: int, side: int, stop: Variant) -> Array[int]:
	var engine: Object = ClassDB.instantiate(&"HintEngine")
	var b := Board.new(seed_value, side)
	b.new_game(side)
	var dirs: Array[int] = []
	while b.can_move():
		if stop is int and b.best_tile >= stop:
			break
		engine.start_custom(b.values, side, SaveStore.HintLevel.MEDIUM, MOVE_BUDGET_MS, 2)
		var dir: int = engine.poll()
		while dir == HintRunner.RUNNING:
			OS.delay_msec(1)
			dir = engine.poll()
		if dir < 0 or not b.move(dir).moved:
			break
		dirs.append(dir)
	return dirs


## Store screenshots, 1080x1920, in one language.
func _store(lang: String) -> void:
	await _open(Vector2i(1080, 1920), Vector2i(720, 1280), lang)
	var dir := "store/screenshots/%s/" % lang
	var first: Array[int] = _moves.first
	await _begin("first")
	_replay(first, first.size() - 1)
	await _final_move(first[-1])
	await _capture(dir + "06-game-over.png", 2.6)
	app._game.close_overlays()

	var main: Array[int] = _moves.main
	await _begin("main")
	var to_2048 := _index_reaching(main, 2048)
	var at_1024 := mini(_index_reaching(main, 1024) + 60, to_2048 - 1)
	_replay(main, at_1024)
	await _capture(dir + "01-game.png")
	_replay(main.slice(at_1024, to_2048), to_2048 - at_1024)
	await _final_move(main[to_2048])
	await _capture(dir + "02-milestone.png", 0.45)
	await _wait(2.4)
	var later := mini(to_2048 + 1 + 150, main.size() - 1)
	_replay(main.slice(to_2048 + 1, later), later - to_2048 - 1)
	app.set_theme_mode(SaveStore.ThemeMode.LIGHT)
	await _capture(dir + "04-game-light.png", 0.8)
	app._open_settings()
	await _capture(dir + "05-settings.png", 0.6)
	app._close_settings()
	app.set_theme_mode(SaveStore.ThemeMode.DARK)
	app._to_menu()
	await _capture(dir + "03-menu.png", 1.2)
	await _close()


## README screenshots at the shape of a tall phone (540x1200).
func _docs_tall() -> void:
	await _open(Vector2i(540, 1200), Vector2i(720, 1600), "ru")
	var dir := "docs/screenshots/"
	var first: Array[int] = _moves.first
	await _begin("first")
	_replay(first, first.size())
	var main: Array[int] = _moves.main
	await _begin("main")
	_replay(main, _index_reaching(main, 2048) + 300)
	app._to_menu()
	await _capture(dir + "menu_dark.png", 1.2)
	app._menu._size.pressed.emit()
	await _capture(dir + "size_picker.png", 0.5)
	app._picker.close()
	app.set_theme_mode(SaveStore.ThemeMode.LIGHT)
	await _capture(dir + "menu_light.png", 1.0)
	app._open_settings()
	await _capture(dir + "settings_light.png", 0.6)
	app.set_theme_mode(SaveStore.ThemeMode.DARK)
	await _capture(dir + "settings_dark.png", 0.8)
	app._close_settings()
	await _wait(0.4)
	app._on_menu_continue()
	await _wait(0.6)
	app._game._ask_new_game()
	await _capture(dir + "confirm_dark.png", 0.7)
	app._confirm.close()
	await _wait(0.3)
	var big: Array[int] = _moves.big
	await _begin("big")
	_replay(big, big.size())
	await _capture(dir + "board_6x6.png", 0.5)
	app.store.tutorial_games = 0
	app._game.start_new(4, true)
	await _capture(dir + "swipe_hint.png", 1.0)
	app._to_menu()
	await _wait(0.4)
	app._open_stats()
	await _capture(dir + "stats.png", 0.6)
	await _close()


## README game screenshots at 9:16 (540x960).
func _docs_game() -> void:
	await _open(Vector2i(540, 960), Vector2i(720, 1280), "ru")
	var dir := "docs/screenshots/"
	var first: Array[int] = _moves.first
	await _begin("first")
	_replay(first, first.size() - 1)
	await _final_move(first[-1])
	await _capture(dir + "game_over_dark.png", 2.6)
	app._game.close_overlays()
	var main: Array[int] = _moves.main
	await _begin("main")
	var to_2048 := _index_reaching(main, 2048)
	_replay(main, to_2048)
	await _final_move(main[to_2048])
	await _capture(dir + "game_milestone_dark.png", 0.45)
	await _wait(2.4)
	var later := mini(to_2048 + 1 + 400, main.size() - 1)
	_replay(main.slice(to_2048 + 1, later), later - to_2048 - 1)
	await _capture(dir + "game_tiles_dark.png", 0.5)
	app.set_theme_mode(SaveStore.ThemeMode.LIGHT)
	await _capture(dir + "game_tiles_light.png", 0.8)
	await _close()


## The landscape layout on a 20:9 phone (960x432).
func _docs_landscape() -> void:
	await _open(Vector2i(960, 432), Vector2i(1600, 720), "ru")
	var big: Array[int] = _moves.big
	await _begin("big")
	_replay(big, big.size())
	await _capture("docs/screenshots/landscape.png", 0.6)
	await _close()


func _docs_tablet() -> void:
	await _open(Vector2i(540, 864), Vector2i(720, 1152), "ru")
	var main: Array[int] = _moves.main
	await _begin("main")
	_replay(main, _index_reaching(main, 2048) + 300)
	app._to_menu()
	await _capture("docs/screenshots/tablet_menu.png", 1.2)
	await _close()


## First move index at which the game's best tile reaches [param tile].
func _index_reaching(dirs: Array[int], tile: int) -> int:
	var spec: Array = GAMES.main
	var b := Board.new(spec[0], spec[1])
	b.new_game(spec[1])
	for i in dirs.size():
		var before := b.best_tile
		b.move(dirs[i])
		if before < tile and b.best_tile >= tile:
			return i
	return dirs.size() - 1


func _open(px: Vector2i, base: Vector2i, lang: String) -> void:
	for f in [SAVE, SAVE + ".bak", SAVE + ".tmp"]:
		DirAccess.remove_absolute(f)
	_vp = SubViewport.new()
	_vp.size = px
	_vp.size_2d_override = base
	_vp.size_2d_override_stretch = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	app = load("res://scenes/main.tscn").instantiate()
	app.store = SaveStore.new(SAVE)
	app.store.tutorial_games = SaveStore.TUTORIAL_GAMES
	_vp.add_child(app)
	await _frames(3)
	app.sfx.music_enabled = false
	app.set_language(lang)
	app.set_theme_mode(SaveStore.ThemeMode.DARK)


func _close() -> void:
	_vp.queue_free()
	await _frames(3)


## Starts game [param name] on the game screen with the board its seed deals.
func _begin(name: String) -> void:
	var spec: Array = GAMES[name]
	app._show_screen(app._game)
	app._game.start_new(spec[1], false)
	app._game.board.rng.seed = spec[0]
	app._game.board.new_game(spec[1])
	app._game.save_state()
	_refresh()
	await _wait(0.3)


## Plays the first [param count] of [param dirs] on the game screen without animating them,
## counting them in the statistics like real moves.
func _replay(dirs: Array[int], count: int) -> void:
	var g := app._game
	for i in mini(count, dirs.size()):
		var r := g.board.move(dirs[i])
		if not r.moved:
			continue
		app.store.record_move(g.board.size)
		app.store.record_best_tile(g.board.size, g.board.best_tile)
		app.store.submit_score(g.board.score, g.board.size)
		app.store.submit_clean_score(g.board.score, g.board.size)
		app.store.add_play_time(g.board.size, SECONDS_PER_MOVE)
	g._best_at_start = app.store.best_for(g.board.size)
	g.save_state()
	_refresh()


## Plays [param dir] through the game screen, with its animation, sound and celebrations.
func _final_move(dir: int) -> void:
	await _wait(0.3)
	app._game.request_move(dir)


func _refresh() -> void:
	var g := app._game
	g._pending_over = not g.board.can_move()
	g._board_view.show_board(g.board)
	g._board_view.hide_hint(true)
	g._refresh_scores(false)


func _capture(file: String, settle := 0.5) -> void:
	await _wait(settle)
	# The app idles in low-processor mode and would stop drawing; a running tween keeps frames coming.
	app.create_tween().tween_interval(0.5)
	await _frames(2)
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://" + file))
	print("shot ", file)


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _frames(n: int) -> void:
	for i in n:
		OS.low_processor_usage_mode = false
		await process_frame
