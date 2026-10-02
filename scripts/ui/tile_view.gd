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
	TileArt.draw(self, Rect2(Vector2.ZERO, size), value, view.tile_styles(value), view.tile_font_size(value))
