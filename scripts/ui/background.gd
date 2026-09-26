class_name Background
extends Control
## Static vertical gradient with two soft color glows. Redraws only on resize or theme change.

var _glow: GradientTexture2D


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	_glow = GradientTexture2D.new()
	_glow.gradient = g
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	_glow.width = 256
	_glow.height = 256


func _on_skin_changed() -> void:
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var p := Palette.current
	var pts := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	draw_polygon(pts, PackedColorArray([p.bg_top, p.bg_top, p.bg_bottom, p.bg_bottom]))
	var r := size.x * 0.95
	var a := 0.10 if p.dark else 0.13
	draw_texture_rect(_glow, Rect2(Vector2(-r * 0.55, -r * 0.5), Vector2(r, r) * 1.3), false, Color(p.accent, a))
	draw_texture_rect(_glow, Rect2(Vector2(size.x - r * 0.6, size.y - r * 0.75), Vector2(r, r) * 1.4), false,
			Color(p.tile_bg(4096), a * 0.9))
