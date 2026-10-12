class_name Toast
extends Control
## Short message in a pill near the bottom of the screen that fades away on its own.
## Passes every touch through.

const HOLD := 4.0
const MAX_WIDTH := 600.0

var _card := Card.make(Design.SPACE_LG, Design.RADIUS_LG, 2)
var _label := SkinLabel.make("", Design.TEXT_CALLOUT, Design.WEIGHT_MEDIUM)
var _tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_card.raised = true
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_label)
	add_child(_card)


## Shows the translation of [param key] for a few seconds.
func show_message(key: String) -> void:
	_label.set_key(key)
	if _tween:
		_tween.kill()
	show()
	_card.modulate.a = 0.0
	_place.call_deferred()
	_tween = create_tween()
	_tween.tween_property(_card, "modulate:a", 1.0, Design.DUR_BASE)
	_tween.tween_interval(HOLD)
	_tween.tween_property(_card, "modulate:a", 0.0, Design.DUR_SLOW)
	_tween.tween_callback(hide)


func is_showing() -> bool:
	return visible


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		_place()


func _place() -> void:
	var width := minf(MAX_WIDTH, size.x - Design.GUTTER * 2.0)
	# A wrapping label measures its height at its current width, which stays stale (zero on the
	# first message) until the card lays it out; give it the final width first.
	_label.size = Vector2(width - _card.padding * 2.0, 0)
	_label.update_minimum_size()
	_card.custom_minimum_size = Vector2(width, 0)
	_card.size = Vector2(width, 0)
	_card.size = _card.get_combined_minimum_size()
	_card.position = Vector2((size.x - _card.size.x) * 0.5, size.y - _card.size.y - Design.SPACE_3XL)
