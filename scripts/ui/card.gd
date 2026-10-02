class_name Card
extends PanelContainer
## Rounded surface panel that follows the palette.

var radius := Design.RADIUS_LG
var padding := Design.SPACE_LG
## Top and bottom padding when it differs from the sides; negative keeps [member padding].
var padding_v := -1.0
## 0 flat, 1 raised (cards), 2 dialog.
var depth := 1
## Fill role: false uses the surface color, true the raised one (popovers, dialogs).
var raised := false


static func make(p_padding := Design.SPACE_LG, p_radius := Design.RADIUS_LG, p_depth := 1) -> Card:
	var c := Card.new()
	c.padding = p_padding
	c.radius = p_radius
	c.depth = p_depth
	return c


func _ready() -> void:
	_on_skin_changed()


func _on_skin_changed() -> void:
	var p := Palette.current
	var box := Design.surface_box(p.surface_raised if raised else p.surface, radius, depth, padding)
	if padding_v >= 0.0:
		box.content_margin_top = padding_v
		box.content_margin_bottom = padding_v
	add_theme_stylebox_override("panel", box)
