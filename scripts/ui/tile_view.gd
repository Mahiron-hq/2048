class_name TileView
extends Control
## One numbered tile. Styles and font sizes come from the owning [BoardView] cache.

var value := 0
var view: BoardView


func set_value(v: int) -> void:
	value = v
	queue_redraw()


func _draw() -> void:
	if value == 0 or view == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var styles := view.tile_styles(value)
	var depth := view.tile_depth()
	draw_style_box(styles[0], rect)
	draw_style_box(styles[1], Rect2(Vector2.ZERO, Vector2(size.x, size.y - depth)))
	var font := view.tile_font()
	var fs := view.tile_font_size(value)
	if fs <= 0:
		return
	var txt := str(value)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var baseline := (size.y - depth) * 0.5 + fs * 0.355
	draw_string(font, Vector2((size.x - w) * 0.5, baseline), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.current.tile_fg(value))
