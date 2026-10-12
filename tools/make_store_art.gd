extends SceneTree
## Renders the promo graphics (feature graphic, banners, itch.io cover) into store/; the store
## screenshots come from tools/make_screenshots.gd. Needs a GPU window:
## godot --path . --script res://tools/make_store_art.gd

const OUT := "res://store/"

const TAGLINE := {"ru": "Спокойная числовая головоломка", "en": "A calm, polished number puzzle"}
const BADGES := {"ru": "Без рекламы  ·  Офлайн  ·  Авторская музыка", "en": "No ads  ·  Offline  ·  Original soundtrack"}



func _initialize() -> void:
	OS.low_processor_usage_mode = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _run() -> void:
	Palette.current = Palette.make(true)
	for lang in ["ru", "en"]:
		await _promo(Vector2i(1024, 500), "feature-graphic-1024x500-%s.png" % lang, lang)
		await _promo(Vector2i(1920, 1080), "banner-1920x1080-%s.png" % lang, lang)
	await _promo(Vector2i(630, 500), "itch-cover-630x500.png", "en")
	quit(0)


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
