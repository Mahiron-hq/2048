class_name Segmented
extends Control
## Two-or-more option selector with a sliding highlight.

signal selected(index: int)

## Finger travel, in screen units, beyond which a touch is a scroll rather than a tap.
const TAP_SLOP := 16.0

var options: PackedStringArray = []
## When true, [member options] are translation keys; otherwise shown verbatim.
var translate := true
var index := 0

var _slide := 0.0:
	set(v):
		_slide = v
		queue_redraw()
var _tween: Tween
var _font: Font = Fonts.sans(Fonts.SEMIBOLD)
var _font_size := 26
var _box := StyleBoxFlat.new()
var _knob := StyleBoxFlat.new()
var _tracking := false
var _press_at := Vector2.ZERO


static func make(p_options: PackedStringArray, p_translate := true) -> Segmented:
	var s := Segmented.new()
	s.options = p_options
	s.translate = p_translate
	return s


func _init() -> void:
	custom_minimum_size = Vector2(300, 60)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Selects [param i] without emitting [signal selected] or animating.
func set_index_silently(i: int) -> void:
	index = i
	_slide = float(i)


func _on_skin_changed() -> void:
	queue_redraw()


func _on_language_changed() -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if options.is_empty():
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		if _tracking and motion.global_position.distance_to(_press_at) > TAP_SLOP:
			_tracking = false
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if mb.pressed:
		_tracking = true
		_press_at = mb.global_position
		return
	# Selecting on release, and only for a tap, keeps a scroll that starts on the control from
	# changing the setting. Screen positions are compared because the control scrolls along
	# with the finger.
	var tap := _tracking and mb.global_position.distance_to(_press_at) <= TAP_SLOP
	_tracking = false
	if tap and Rect2(Vector2.ZERO, size).has_point(mb.position):
		_select(clampi(int(mb.position.x / (size.x / options.size())), 0, options.size() - 1))


func _select(i: int) -> void:
	if i == index:
		return
	index = i
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_slide", float(i), 0.2)
	if App.instance:
		App.instance.feedback_click()
	selected.emit(i)


func _draw() -> void:
	if options.is_empty():
		return
	var p := Palette.current
	var box := _box
	box.bg_color = p.surface_pressed if not p.dark else p.bg_bottom
	box.set_corner_radius_all(int(size.y * 0.5))
	box.corner_detail = 12
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var seg_w := size.x / options.size()
	var pad := 5.0
	var knob := _knob
	knob.bg_color = p.accent
	knob.set_corner_radius_all(int(size.y * 0.5 - pad))
	knob.corner_detail = 12
	knob.shadow_color = Color(p.accent, 0.3)
	knob.shadow_size = 6
	draw_style_box(knob, Rect2(Vector2(_slide * seg_w + pad, pad), Vector2(seg_w - pad * 2, size.y - pad * 2)))
	for i in options.size():
		var label: String = I18n.t(options[i]) if translate else options[i]
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
		var weight := clampf(1.0 - absf(_slide - i), 0.0, 1.0)
		var color := p.text_muted.lerp(p.accent_text, weight)
		draw_string(_font, Vector2(i * seg_w + (seg_w - w) * 0.5, size.y * 0.5 + _font_size * 0.36), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, color)
