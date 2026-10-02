extends SceneTree
## Renders store screenshots (1080x1920, RU/EN) and promo graphics into store/. Needs a GPU window:
## godot --path . --script res://tools/make_store_art.gd

const OUT := "res://store/"
const SAVE := "user://store_art_save.json"

const TAGLINE := {"ru": "Спокойная головоломка слияний", "en": "A calm, polished number puzzle"}
const BADGES := {"ru": "Без рекламы  ·  Офлайн  ·  Авторская музыка", "en": "No ads  ·  Offline  ·  Original soundtrack"}

var app: App
var _vp: SubViewport


func _initialize() -> void:
	OS.low_processor_usage_mode = false
	for dir in ["screenshots/ru", "screenshots/en"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + dir))
	_run.call_deferred()


func _run() -> void:
	await _screenshots()
	Palette.current = Palette.make(true)
	for lang in ["ru", "en"]:
		await _promo(Vector2i(1024, 500), "feature-graphic-1024x500-%s.png" % lang, lang)
		await _promo(Vector2i(1920, 1080), "banner-1920x1080-%s.png" % lang, lang)
	await _promo(Vector2i(630, 500), "itch-cover-630x500.png", "en")
	quit(0)


func _screenshots() -> void:
	DirAccess.remove_absolute(SAVE)
	_vp = _make_viewport(Vector2i(1080, 1920))
	_vp.size_2d_override = Vector2i(720, 1280)
	_vp.size_2d_override_stretch = true
	app = load("res://scenes/main.tscn").instantiate()
	app.store = SaveStore.new(SAVE)
	_vp.add_child(app)
	await _frames(3)
	app.sfx.music_enabled = false
	for lang in ["ru", "en"]:
		app.set_language(lang)
		app.set_theme_mode(SaveStore.ThemeMode.DARK)
		var dir := "screenshots/%s/" % lang

		app._start_new_game()
		await _wait(0.6)
		_board([[2, 8, 4, 2], [16, 64, 32, 4], [128, 256, 8, 2], [1024, 512, 16, 4]], 11248, 11248)
		await _capture(dir + "01-game.png")

		_board([[1024, 1024, 8, 2], [256, 32, 4, 0], [16, 8, 2, 0], [4, 2, 0, 0]], 18904, 18904)
		await _wait(0.4)
		app._game.request_move(Board.Dir.LEFT)
		await _wait(0.5)
		await _capture(dir + "02-milestone.png", 0.0)
		await _wait(2.2)

		app.store.submit_score(20932, 4)
		app._to_menu()
		await _wait(1.2)
		await _capture(dir + "03-menu.png")

		app.set_theme_mode(SaveStore.ThemeMode.LIGHT)
		app._start_new_game()
		await _wait(0.6)
		_board([[4, 2, 0, 2], [8, 32, 16, 4], [64, 128, 256, 8], [2048, 512, 32, 2]], 26780, 26780)
		await _capture(dir + "04-game-light.png")

		app._open_settings()
		await _wait(0.6)
		await _capture(dir + "05-settings.png")
		app._close_settings()
		await _wait(0.5)

		app.set_theme_mode(SaveStore.ThemeMode.DARK)
		app._game.start_new()
		await _wait(0.4)
		app.store.submit_score(30000, 4)
		app._game._best_at_start = 30000
		_board([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 16], [4, 2, 1024, 1024]], 31940, 31940)
		app._game._best_at_start = 30000
		await _wait(0.3)
		app._game.request_move(Board.Dir.LEFT)
		await _wait(2.6)
		await _capture(dir + "06-game-over.png")
		app._game.close_overlays()
		await _wait(0.4)
	_vp.queue_free()
	await _frames(2)


func _board(rows: Array, score: int, best: int) -> void:
	var flat := []
	for r in rows:
		flat.append_array(r)
	var g := app._game
	g.board.from_dict({"size": 4, "values": flat, "score": score, "moves": 412})
	g._pending_over = false
	app.store.submit_score(best, 4)
	g._board_view.show_board(g.board)
	g._board_view.hide_hint(true)
	g._refresh_scores(false)


func _promo(px: Vector2i, file: String, lang: String) -> void:
	var vp := _make_viewport(px)
	var art := _Promo.new()
	art.tagline = TAGLINE[lang]
	art.badges = BADGES[lang]
	art.size = Vector2(px)
	vp.add_child(art)
	await _frames(3)
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file))
	print("art ", file)
	vp.queue_free()


func _make_viewport(px: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = px
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	return vp


## Saves the screenshot viewport; [param settle] keeps frames flowing while animations finish.
func _capture(file: String, settle := 0.5) -> void:
	if settle > 0.0:
		await _wait(settle)
	# The app drops to low-processor mode when idle and would stop drawing; a running tween keeps it awake.
	app.create_tween().tween_interval(0.5)
	await _frames(2)
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file))
	print("shot ", file)


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _frames(n: int) -> void:
	for i in n:
		OS.low_processor_usage_mode = false
		await process_frame


## Promo card: the dark theme's background, the 2-0-4-8 logo tiles, title, tagline and features.
class _Promo:
	extends Control

	const DIGITS := ["2", "0", "4", "8"]

	var tagline := ""
	var badges := ""

	func _draw() -> void:
		var p := Palette.current
		var w := size.x
		var h := size.y
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
				PackedColorArray([p.bg, p.bg, p.bg_deep, p.bg_deep]))

		var unit := minf(w / 1024.0, h / 500.0)
		if w / h < 1.5:
			unit = minf(w / 630.0, h / 500.0) * 0.82
		var tile := 112.0 * unit
		var gap := Design.SPACE_MD * unit
		var row_w := tile * 4 + gap * 3
		var title_size := int(Design.TEXT_DISPLAY * 0.86 * unit)
		var tag_size := int(Design.TEXT_HEADLINE * unit)
		var badge_size := int(Design.TEXT_CALLOUT * unit)
		var block_h := tile + Design.SPACE_XL * unit + title_size + Design.SPACE_MD * unit + tag_size \
				+ Design.SPACE_LG * unit + badge_size
		var y := (h - block_h) * 0.5
		var x := (w - row_w) * 0.5
		for i in 4:
			var value: int = MenuScreen.LOGO_VALUES[i]
			var fs := Fonts.fit(TileArt.font(), DIGITS[i], int(tile * 0.6), tile * TileArt.TEXT_ROOM)
			TileArt.draw(self, Rect2(x + i * (tile + gap), y, tile, tile), value, TileArt.styles(value, tile), fs, DIGITS[i])
		y += tile + Design.SPACE_XL * unit
		Fonts.draw_centered(self, Fonts.sans(Design.WEIGHT_HEAVY), "2048 Merge", Vector2(w * 0.5, y + title_size * 0.5), title_size, p.text)
		y += title_size + Design.SPACE_MD * unit
		Fonts.draw_centered(self, Fonts.sans(Design.WEIGHT_MEDIUM), tagline, Vector2(w * 0.5, y + tag_size * 0.5), tag_size, p.text_secondary)
		y += tag_size + Design.SPACE_LG * unit
		Fonts.draw_centered(self, Fonts.sans(Design.WEIGHT_BOLD), badges, Vector2(w * 0.5, y + badge_size * 0.5), badge_size, p.accent)
