extends SceneTree
## Captures every screen on phone and tablet form factors, portrait and landscape, for visual
## review: godot --path . --script res://tests/layout_shots.gd  (writes screenshots/layout/*.png)
## Each device is rendered offscreen at its native resolution with the same stretch rules the
## project uses (canvas_items, expand, 720-unit short side per orientation).

const OUT := "res://screenshots/layout/"
const SAVE := "user://layout_shots.json"
const DEVICES := {
	"phone": Vector2i(1080, 2400),
	"phone-land": Vector2i(2400, 1080),
	"tablet": Vector2i(1600, 2560),
	"tablet-land": Vector2i(2560, 1600),
	"phone-land-16x9": Vector2i(1920, 1080),
	"tablet-land-4x3": Vector2i(2048, 1536),
}

var app: App
var _vp: SubViewport


func _initialize() -> void:
	OS.low_processor_usage_mode = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _run() -> void:
	for device in DEVICES:
		await _device(device, DEVICES[device])
	quit(0)


func _device(tag: String, px: Vector2i) -> void:
	DirAccess.remove_absolute(SAVE)
	_vp = SubViewport.new()
	_vp.size = px
	var base := Vector2(1280, 720) if px.x > px.y else Vector2(720, 1280)
	var k := minf(px.x / base.x, px.y / base.y)
	_vp.size_2d_override = Vector2i(roundi(px.x / k), roundi(px.y / k))
	_vp.size_2d_override_stretch = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	app = load("res://scenes/main.tscn").instantiate()
	app.store = SaveStore.new(SAVE)
	_vp.add_child(app)
	await _frames(3)
	app.sfx.music_enabled = false
	app.set_language("ru")
	app.set_theme_mode(SaveStore.ThemeMode.DARK)
	app.store.submit_score(20932, 4)
	app._to_menu()
	await _capture(tag + "-1-menu", 1.0)

	app._menu._size.pressed.emit()
	await _capture(tag + "-2-size-picker", 0.4)
	app._picker._list.get_child(0).pressed.emit()
	await _wait(0.3)

	app._menu._play.pressed.emit()
	await _capture(tag + "-3-hint-3x3", 0.9)

	app.selected_size = 6
	app._game.start_new(6, false)
	app._game.board.from_dict({"size": 6, "values": [
		2, 4, 8, 16, 32, 64,
		128, 256, 512, 1024, 2048, 4096,
		0, 2, 4, 2, 8, 0,
		0, 0, 2, 0, 0, 0,
		0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 2], "score": 48212, "moves": 900})
	app._game._board_view.show_board(app._game.board)
	app._game._board_view.hide_hint(true)
	app._game._refresh_scores(false)
	await _capture(tag + "-4-game-6x6", 0.4)

	# Theme switched rapidly, captured mid-crossfade: the fading snapshot must match the screen.
	app.set_show_fps(true)
	for mode in [SaveStore.ThemeMode.LIGHT, SaveStore.ThemeMode.DARK, SaveStore.ThemeMode.LIGHT]:
		app.set_theme_mode(mode)
		await _frames(3)
	var fades := app.get_children().filter(func(c: Node) -> bool: return c is TextureRect)
	for fade: TextureRect in fades:
		print("theme fade %s vs screen %s" % [fade.size, app.size])
	await _capture(tag + "-4b-theme-fade", 0.05)
	app.set_show_fps(false)

	app.set_theme_mode(SaveStore.ThemeMode.LIGHT)
	app._open_settings()
	await _capture(tag + "-5-settings", 0.6)
	app._close_settings()
	await _wait(0.3)

	app.store.record_game(4, 12480, 1024)
	app.store.record_game(6, 48212, 4096)
	app.store.add_play_time(4, 7560)
	for i in 1234:
		app.store.record_move(4)
	app._to_menu()
	await _wait(0.3)
	app._open_stats()
	await _capture(tag + "-6-stats", 0.6)

	_vp.queue_free()
	await _frames(3)


func _capture(file: String, settle: float) -> void:
	await _wait(settle)
	# The app idles in low-processor mode and would stop drawing; a running tween keeps frames coming.
	app.create_tween().tween_interval(0.5)
	await _frames(2)
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file + ".png"))
	print("shot ", file)


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _frames(n: int) -> void:
	for i in n:
		OS.low_processor_usage_mode = false
		await process_frame
