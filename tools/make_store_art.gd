extends SceneTree
## Renders store screenshots (1080x1920, RU/EN) and promo graphics into store/. Needs a GPU window:
## godot --path . --script res://tools/make_store_art.gd
## Uses Roboto (the Android system font) from build/fonts/Roboto-VF.ttf when present, so the
## captures look like the game on a phone rather than with the desktop's system font.

const OUT := "res://store/"
const SAVE := "user://store_art_save.json"
const ROBOTO := "res://build/fonts/Roboto-VF.ttf"

const TAGLINE := {"ru": "Спокойная головоломка слияний", "en": "A calm, polished number puzzle"}
const BADGES := {"ru": "Без рекламы  ·  Офлайн  ·  Авторская музыка", "en": "No ads  ·  Offline  ·  Original soundtrack"}

var app: App
var _vp: SubViewport


func _initialize() -> void:
	OS.low_processor_usage_mode = false
	_use_roboto()
	for dir in ["screenshots/ru", "screenshots/en"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + dir))
	_run.call_deferred()


func _run() -> void:
	await _screenshots()
	for lang in ["ru", "en"]:
		await _promo(Vector2i(1024, 500), "feature-graphic-1024x500-%s.png" % lang, lang)
		await _promo(Vector2i(1920, 1080), "banner-1920x1080-%s.png" % lang, lang)
	await _promo(Vector2i(630, 500), "itch-cover-630x500.png", "en")
	quit(0)


func _use_roboto() -> void:
	var path := ProjectSettings.globalize_path(ROBOTO)
	if not FileAccess.file_exists(path):
		push_warning("Roboto not found; captures use the system font")
		return
	var file := FontFile.new()
	if file.load_dynamic_font(path) != OK:
		return
	var ts := TextServerManager.get_primary_interface()
	for weight in [Fonts.REGULAR, Fonts.MEDIUM, Fonts.SEMIBOLD, Fonts.BOLD, Fonts.BLACK]:
		for tabular in [false, true]:
			var v := FontVariation.new()
			v.base_font = file
			v.variation_opentype = {ts.name_to_tag("wght"): weight}
			if tabular:
				v.opentype_features = {ts.name_to_tag("tnum"): 1}
			Fonts._cache[weight * 2 + int(tabular)] = v


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
	# Freeing the app clears the font cache; restore Roboto for the promo art.
	_use_roboto()


func _board(rows: Array, score: int, best: int) -> void:
	var flat := []
	for r in rows:
		flat.append_array(r)
	var g := app._game
	g.board.from_dict({"size": 4, "values": flat, "score": score, "moves": 412})
	g._pending_over = false
	app.store.submit_score(best, 4)
	g._board_view.show_board(g.board)
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


## Promo card: dark gradient, the 2-0-4-8 tiles, title, tagline and feature line.
class _Promo:
	extends Control

	const VALUES := [2, 16, 128, 2048]
	const DIGITS := ["2", "0", "4", "8"]

	var tagline := ""
	var badges := ""

	func _draw() -> void:
		var p := Palette.make(true)
		var w := size.x
		var h := size.y
		var top := Color("2a2440")
		var bottom := Color("120f1a")
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
				PackedColorArray([top, top.lerp(bottom, 0.35), bottom, top.lerp(bottom, 0.7)]))
		_glow(Vector2(w * 0.12, h * 0.1), h * 0.9, Color(p.accent, 0.16))
		_glow(Vector2(w * 0.92, h * 0.95), h * 1.0, Color(p.tile_bg(4096), 0.16))

		var unit := minf(w / 1024.0, h / 500.0)
		if w / h < 1.5:
			unit = minf(w / 630.0, h / 500.0) * 0.82
		var tile := 118.0 * unit
		var gap := 16.0 * unit
		var row_w := tile * 4 + gap * 3
		var title_size := int(84 * unit)
		var tag_size := int(34 * unit)
		var badge_size := int(24 * unit)
		var block_h := tile + 36 * unit + title_size + 18 * unit + tag_size + 26 * unit + badge_size
		var y := (h - block_h) * 0.5
		var x := (w - row_w) * 0.5
		for i in 4:
			_tile(Rect2(x + i * (tile + gap), y, tile, tile), VALUES[i], DIGITS[i], p)
		y += tile + 36 * unit
		_centered("2048 Merge", Fonts.sans(Fonts.BLACK), title_size, y + title_size * 0.8, p.text)
		y += title_size + 18 * unit
		_centered(tagline, Fonts.sans(Fonts.MEDIUM), tag_size, y + tag_size * 0.8, Color(p.text, 0.85))
		y += tag_size + 26 * unit
		_centered(badges, Fonts.sans(Fonts.SEMIBOLD), badge_size, y + badge_size * 0.8, p.accent)

	func _centered(text: String, font: Font, fs: int, baseline: float, color: Color) -> void:
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - tw) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

	func _glow(center: Vector2, radius: float, color: Color) -> void:
		for i in 24:
			var t := i / 24.0
			draw_circle(center, radius * (1.0 - t), Color(color, color.a * 0.09 * (0.3 + t)), true, -1.0, true)

	func _tile(r: Rect2, value: int, label: String, p: Palette) -> void:
		var bg := p.tile_bg(value)
		var depth := r.size.y * 0.06
		var base := StyleBoxFlat.new()
		base.bg_color = bg.darkened(0.25)
		base.set_corner_radius_all(int(r.size.x * 0.2))
		base.corner_detail = 12
		if p.tile_glows(value):
			base.shadow_color = Color(bg, 0.45)
			base.shadow_size = int(r.size.x * 0.18)
		draw_style_box(base, r)
		var face := base.duplicate() as StyleBoxFlat
		face.bg_color = bg
		face.shadow_size = 0
		draw_style_box(face, Rect2(r.position, Vector2(r.size.x, r.size.y - depth)))
		var font := Fonts.sans(Fonts.BLACK)
		var fs := int(r.size.x * 0.62)
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, r.position + Vector2((r.size.x - tw) * 0.5, (r.size.y - depth) * 0.5 + fs * 0.355), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, p.tile_fg(value))
