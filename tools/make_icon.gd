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


class IconArt:
	extends Control

	const DIGITS := ["2", "0", "4", "8"]
	const VALUES := [2, 16, 128, 2048]

	var mode := "full"

	func _draw() -> void:
		var p := Palette.make(true)
		var s := size.x
		if mode in ["full", "rounded", "background"]:
			var top := Color("2a2440")
			var bottom := Color("120f1a")
			if mode == "rounded":
				var box := StyleBoxFlat.new()
				box.bg_color = top.lerp(bottom, 0.5)
				box.set_corner_radius_all(int(s * 0.22))
				box.corner_detail = 16
				draw_style_box(box, Rect2(Vector2.ZERO, size))
			else:
				draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s, 0), Vector2(s, s), Vector2(0, s)]),
						PackedColorArray([top, top.lerp(bottom, 0.4), bottom, top.lerp(bottom, 0.6)]))
		if mode == "background":
			return
		# Adaptive foregrounds must keep content inside the central 66% safe zone.
		var extent := s * (0.5 if mode in ["foreground", "mono"] else 0.62)
		var gap := extent * 0.07
		var tile := (extent - gap) * 0.5
		var origin := (size - Vector2(extent, extent)) * 0.5
		var font := Fonts.sans(Fonts.BLACK)
		for i in 4:
			var pos := origin + Vector2((i % 2) * (tile + gap), (i / 2) * (tile + gap))
			var bg := p.tile_bg(VALUES[i])
			var fg := p.tile_fg(VALUES[i])
			if mode == "mono":
				bg = Color.WHITE
				fg = Color(0, 0, 0, 0)
			var depth := tile * 0.06
			var base := StyleBoxFlat.new()
			base.bg_color = bg.darkened(0.25) if mode != "mono" else bg
			base.set_corner_radius_all(int(tile * 0.2))
			base.corner_detail = 12
			if mode == "full" and p.tile_glows(VALUES[i]):
				base.shadow_color = Color(bg, 0.45)
				base.shadow_size = int(tile * 0.18)
			draw_style_box(base, Rect2(pos, Vector2(tile, tile)))
			var face := base.duplicate() as StyleBoxFlat
			face.bg_color = bg
			face.shadow_size = 0
			draw_style_box(face, Rect2(pos, Vector2(tile, tile - depth)))
			if mode == "mono":
				continue
			var fs := int(tile * 0.66)
			var w := font.get_string_size(DIGITS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, pos + Vector2((tile - w) * 0.5, (tile - depth) * 0.5 + fs * 0.355), DIGITS[i],
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)
