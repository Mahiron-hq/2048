class_name TileBadge
extends Control
## Standalone tile graphic for logos and stats, colored like the board tile of [member value].

var value := 2:
	set(v):
		value = v
		queue_redraw()
## Text shown instead of the value when not empty.
var label := ""
var text_ratio := 0.5

var _base := StyleBoxFlat.new()
var _face := StyleBoxFlat.new()
var _font: Font = Fonts.sans(Fonts.BLACK)


static func make(p_value: int, side: float, p_label := "") -> TileBadge:
	var b := TileBadge.new()
	b.value = p_value
	b.label = p_label
	b.custom_minimum_size = Vector2(side, side)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5


func _on_skin_changed() -> void:
	queue_redraw()


func _draw() -> void:
	var p := Palette.current
	var bg := p.tile_bg(value)
	var side := minf(size.x, size.y)
	var depth := roundf(side * 0.05)
	var radius := int(side * 0.18)
	_base.bg_color = bg.darkened(0.16 if not p.dark else 0.3)
	_base.set_corner_radius_all(radius)
	_base.corner_detail = 10
	_base.shadow_color = Color(bg, 0.5) if p.tile_glows(value) else p.shadow
	_base.shadow_size = int(side * (0.16 if p.tile_glows(value) else 0.06))
	_face.bg_color = bg
	_face.set_corner_radius_all(radius)
	_face.corner_detail = 10
	draw_style_box(_base, Rect2(Vector2.ZERO, size))
	draw_style_box(_face, Rect2(Vector2.ZERO, Vector2(size.x, size.y - depth)))
	var txt := label if not label.is_empty() else str(value)
	var fs := int(side * text_ratio)
	var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while w > size.x * 0.84 and fs > 8:
		fs -= 1
		w = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, Vector2((size.x - w) * 0.5, (size.y - depth) * 0.5 + fs * 0.355), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, p.tile_fg(value))
