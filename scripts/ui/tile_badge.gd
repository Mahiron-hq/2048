class_name TileBadge
extends Control
## Standalone tile for logos and stats, colored like the board tile of [member value].

var value := 2:
	set(v):
		value = v
		queue_redraw()
## Text shown instead of the value when not empty.
var label := ""
## Text size as a share of the side; 0 sizes it like a board tile.
var text_ratio := 0.0


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
	var side := minf(size.x, size.y)
	var text := label if not label.is_empty() else str(value)
	var fs := TileArt.font_size(text, side)
	if text_ratio > 0.0:
		fs = Fonts.fit(TileArt.font(), text, int(side * text_ratio), side * TileArt.TEXT_ROOM, 8)
	TileArt.draw(self, Rect2(Vector2.ZERO, size), value, TileArt.styles(value, side), fs, label)
