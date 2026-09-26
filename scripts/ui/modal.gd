class_name Modal
extends Control
## Full-screen scrim with a centered card that scales in. Subclasses fill [member body].

signal closed

var body := VBoxContainer.new()
var is_open := false

var _scrim := ColorRect.new()
var _card := Card.make(44, 44)
var _center := CenterContainer.new()
var _tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scrim)
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_card.custom_minimum_size = Vector2(560, 0)
	_center.add_child(_card)
	body.add_theme_constant_override("separation", 22)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_child(body)


func _ready() -> void:
	_on_skin_changed()


func _on_skin_changed() -> void:
	_scrim.color = Palette.current.scrim


func open() -> void:
	if _tween:
		_tween.kill()
	is_open = true
	show()
	_card.custom_minimum_size.x = minf(600.0, get_viewport_rect().size.x - 64.0)
	_scrim.modulate.a = 0.0
	_card.modulate.a = 0.0
	await get_tree().process_frame
	if not is_open:
		return
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.86, 0.86)
	_tween = create_tween().set_parallel()
	_tween.tween_property(_scrim, "modulate:a", 1.0, 0.24)
	_tween.tween_property(_card, "modulate:a", 1.0, 0.2).set_delay(0.05)
	_tween.tween_property(_card, "scale", Vector2.ONE, 0.36).set_delay(0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not is_open:
		return
	is_open = false
	if _tween:
		_tween.kill()
	_card.pivot_offset = _card.size * 0.5
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_scrim, "modulate:a", 0.0, 0.18)
	_tween.tween_property(_card, "modulate:a", 0.0, 0.15)
	_tween.tween_property(_card, "scale", Vector2(0.94, 0.94), 0.18)
	_tween.chain().tween_callback(hide)
	closed.emit()


static func button_row(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for b in buttons:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	return row
