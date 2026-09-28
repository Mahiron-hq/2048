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
## Pop-in progress multiplied into the card's fit-to-screen scale.
var _pop := 1.0:
	set(v):
		_pop = v
		_apply_scale()


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
	_card.resized.connect(_apply_scale)
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
	_scrim.modulate.a = 0.0
	_card.modulate.a = 0.0
	_fit_card()
	_pop = 0.86
	_tween = create_tween().set_parallel()
	_tween.tween_property(_scrim, "modulate:a", 1.0, 0.24)
	_tween.tween_property(_card, "modulate:a", 1.0, 0.2).set_delay(0.05)
	_tween.tween_property(self, "_pop", 1.0, 0.36).set_delay(0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not is_open:
		return
	is_open = false
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_scrim, "modulate:a", 0.0, 0.18)
	_tween.tween_property(_card, "modulate:a", 0.0, 0.15)
	_tween.tween_property(self, "_pop", 0.94, 0.18)
	_tween.chain().tween_callback(hide)
	closed.emit()


## Draws the dialog for a couple of frames, practically transparent and click-through, so its
## glyphs and styles are cached before the first real opening, which otherwise drops frames on
## slow phones.
func prime() -> void:
	if is_open:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.01
	_scrim.modulate.a = 1.0
	_card.modulate.a = 1.0
	_pop = 1.0
	show()
	for i in 2:
		await get_tree().process_frame
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	if not is_open:
		hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		_fit_card()


func _fit_card() -> void:
	_card.custom_minimum_size.x = minf(600.0, size.x - 64.0)
	_apply_scale()


## Scales the card about its center. Wrapped text settles its height over a few layout passes,
## so this runs again on every card resize instead of trusting the size seen at open time.
func _apply_scale() -> void:
	_card.pivot_offset = _card.size * 0.5
	# Short landscape screens: shrink the card to fit instead of letting it spill off screen.
	var fit := 1.0
	if size.y > 64.0 and _card.size.y > 0.0:
		fit = minf(1.0, (size.y - 32.0) / _card.size.y)
	_card.scale = Vector2.ONE * (fit * _pop)


static func button_row(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for b in buttons:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	return row
