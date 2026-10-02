extends SceneTree
## Renders the launcher icons into assets/icons/. Needs a GPU window:
## godot --path . --script res://tools/make_icon.gd

const OUT := "res://assets/icons/"
const SPECS := [
	["icon.png", 1024, "full"],
	["icon_192.png", 192, "rounded"],
	["adaptive_background.png", 432, "background"],
	["adaptive_foreground.png", 432, "foreground"],
	["adaptive_monochrome.png", 432, "mono"],
]


func _initialize() -> void:
	# The project idles in low-processor mode, which would skip the frames we need to render.
	OS.low_processor_usage_mode = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_render.call_deferred()


func _render() -> void:
	Palette.current = Palette.make(true)
	for spec in SPECS:
		var vp := SubViewport.new()
		vp.size = Vector2i(spec[1], spec[1])
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var art := IconArt.new()
		art.mode = spec[2]
		art.size = Vector2(spec[1], spec[1])
		vp.add_child(art)
		root.add_child(vp)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(OUT + spec[0]))
		print("icon ", spec[0])
		vp.queue_free()
	quit(0)


## The 2-0-4-8 tiles of the menu logo, two by two, on the dark theme's background.
class IconArt:
	extends Control

	const DIGITS := ["2", "0", "4", "8"]

	var mode := "full"

	func _draw() -> void:
		var p := Palette.current
		var s := size.x
		if mode in ["full", "rounded", "background"]:
			var box := StyleBoxFlat.new()
			box.bg_color = p.surface
			box.set_corner_radius_all(int(s * 0.22) if mode == "rounded" else 0)
			box.corner_detail = 16
			box.anti_aliasing = true
			draw_style_box(box, Rect2(Vector2.ZERO, size))
		if mode == "background":
			return
		# Adaptive foregrounds must keep content inside the central 66% safe zone.
		var extent := s * (0.5 if mode in ["foreground", "mono"] else 0.62)
		var gap := extent * 0.07
		var tile := (extent - gap) * 0.5
		var origin := (size - Vector2(extent, extent)) * 0.5
		for i in 4:
			var value: int = MenuScreen.LOGO_VALUES[i]
			var rect := Rect2(origin + Vector2((i % 2) * (tile + gap), (i / 2) * (tile + gap)), Vector2(tile, tile))
			var box := TileArt.styles(value, tile)
			if mode == "mono":
				for b: StyleBoxFlat in box:
					b.bg_color = Color.WHITE
					b.border_width_top = 0
				TileArt.draw_face(self, rect, box, TileArt.depth(tile))
				continue
			var fs := Fonts.fit(TileArt.font(), DIGITS[i], int(tile * 0.64), tile * TileArt.TEXT_ROOM)
			TileArt.draw(self, rect, value, box, fs, DIGITS[i])
