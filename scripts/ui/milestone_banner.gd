class_name MilestoneBanner
extends Control
## Pill in the new tile's color that drops in from the top to celebrate a milestone, then leaves.
## Does not block input and never pauses the game.

const HOLD := 1.5
const HEIGHT := Design.CONTROL_MD

## Resting y position inside the parent while shown.
var rest_y := 0.0

var _value := 128
var _font: Font = Fonts.sans(Design.WEIGHT_HEAVY)
var _box: StyleBoxFlat
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	custom_minimum_size = Vector2(0, HEIGHT)


func celebrate(value: int) -> void:
	_value = value
	_box = null
	var text := I18n.t("MILESTONE") % value
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Design.TEXT_BODY).x \
			+ Design.ICON_MD + Design.SPACE_SM + Design.SPACE_XL * 2.0
	var parent_w := get_parent_control().size.x if get_parent_control() else 720.0
	size = Vector2(minf(w, parent_w - Design.GUTTER), HEIGHT)
	pivot_offset = size * 0.5
	if _tween:
		_tween.kill()
	position.x = (parent_w - size.x) * 0.5
	var rest := rest_y
	var away := rest - HEIGHT - Design.SPACE_2XL
	position.y = away
	modulate.a = 0.0
	scale = Vector2(0.94, 0.94)
	show()
	queue_redraw()
	_tween = create_tween()
	_tween.set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", rest, Design.DUR_SLOW * 1.2)
	_tween.tween_property(self, "modulate:a", 1.0, Design.DUR_BASE)
	_tween.tween_property(self, "scale", Vector2.ONE, Design.DUR_SLOW * 1.2)
	_tween.chain().tween_interval(HOLD)
	_tween.chain().tween_property(self, "position:y", away, Design.DUR_SLOW).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, Design.DUR_SLOW).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(hide)


func _on_skin_changed() -> void:
	_box = null
	queue_redraw()


func _draw() -> void:
	var p := Palette.current
	if _box == null:
		_box = Design.surface_box(p.tile_bg(_value), size.y * 0.5, 2)
		_box.border_width_top = 0
		_box.border_width_bottom = 0
		_box.border_width_left = 0
		_box.border_width_right = 0
	draw_style_box(_box, Rect2(Vector2.ZERO, size))
	var fg := p.tile_fg(_value)
	var text := I18n.t("MILESTONE") % _value
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Design.TEXT_BODY).x
	var x := (size.x - w - Design.ICON_MD - Design.SPACE_SM) * 0.5
	Icons.draw(self, Icons.Kind.TROPHY, Vector2(x + Design.ICON_MD * 0.5, size.y * 0.5), Design.ICON_MD, fg)
	draw_string(_font, Vector2(x + Design.ICON_MD + Design.SPACE_SM, Fonts.baseline(size.y * 0.5, Design.TEXT_BODY)), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, Design.TEXT_BODY, fg)
