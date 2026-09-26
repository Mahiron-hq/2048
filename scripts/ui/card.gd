class_name Card
extends PanelContainer
## Rounded surface panel that follows the palette.

var radius := 36
var padding := 32
var elevated := true


static func make(p_padding := 32, p_radius := 36) -> Card:
	var c := Card.new()
	c.padding = p_padding
	c.radius = p_radius
	return c


func _ready() -> void:
	_on_skin_changed()


func _on_skin_changed() -> void:
	var p := Palette.current
	var box := StyleBoxFlat.new()
	box.bg_color = p.surface
	box.set_corner_radius_all(radius)
	box.corner_detail = 12
	box.set_content_margin_all(padding)
	box.border_color = p.surface_border
	box.set_border_width_all(0 if p.dark else 1)
	if elevated:
		box.shadow_color = p.shadow
		box.shadow_size = 18
		box.shadow_offset = Vector2(0, 8)
	add_theme_stylebox_override("panel", box)
