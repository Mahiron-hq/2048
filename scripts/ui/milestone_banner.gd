class_name MilestoneBanner
extends Control
## Pill that drops in from the top to celebrate a new tile milestone, then leaves.
## Does not block input and never pauses the game.

const HOLD := 1.5

## Resting y position inside the parent while shown.
var rest_y := 0.0

var _value := 128
var _font: Font = Fonts.sans(Fonts.BOLD)
var _box := StyleBoxFlat.new()
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	custom_minimum_size = Vector2(0, 84)


func celebrate(value: int) -> void:
	_value = value
	var text := I18n.t("MILESTONE") % value
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 140
	var parent_w := get_parent_control().size.x if get_parent_control() else 720.0
	size = Vector2(minf(w, parent_w - 32), 84)
	pivot_offset = size * 0.5
	if _tween:
		_tween.kill()
	position.x = (parent_w - size.x) * 0.5
	var rest := rest_y
	position.y = rest - 140
	modulate.a = 0.0
	scale = Vector2(0.9, 0.9)
	show()
	queue_redraw()
	_tween = create_tween()
	_tween.set_parallel()
	_tween.tween_property(self, "position:y", rest, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(HOLD)
	_tween.chain().tween_property(self, "position:y", rest - 140, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.28)
	_tween.chain().tween_callback(hide)


func _on_skin_changed() -> void:
	queue_redraw()


func _draw() -> void:
	var p := Palette.current
	var bg := p.tile_bg(_value)
	_box.bg_color = bg
	_box.set_corner_radius_all(int(size.y * 0.5))
	_box.corner_detail = 12
	_box.shadow_color = Color(bg, 0.6)
	_box.shadow_size = 22
	draw_style_box(_box, Rect2(Vector2.ZERO, size))
	var fg := p.tile_fg(_value)
	var text := I18n.t("MILESTONE") % _value
	Icons.draw(self, Icons.Kind.TROPHY, Vector2(52, size.y * 0.5), 34, fg)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	var x := maxf(84.0, (size.x - w) * 0.5 + 20)
	draw_string(_font, Vector2(x, size.y * 0.5 + 30 * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, fg)
