class_name Segmented
extends Control
## Selector for two or more options: a raised knob slides to the chosen one.

signal selected(index: int)

## Finger travel, in screen units, beyond which a touch is a scroll rather than a tap.
const TAP_SLOP := 16.0
const KNOB_INSET := 4.0

var options: PackedStringArray = []
## When true, [member options] are translation keys; otherwise shown verbatim.
var translate := true
var index := 0

var _slide := 0.0:
	set(v):
		_slide = v
		queue_redraw()
var _tween: Tween
var _font: Font = Fonts.sans(Design.WEIGHT_BOLD)
var _track: StyleBoxFlat
var _knob: StyleBoxFlat
var _tracking := false
var _press_at := Vector2.ZERO


static func make(p_options: PackedStringArray, p_translate := true) -> Segmented:
	var s := Segmented.new()
	s.options = p_options
	s.translate = p_translate
	return s


func _init() -> void:
	custom_minimum_size = Vector2(Design.CONTROL_SM * 4.0, Design.CONTROL_SM)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _notification(what: int) -> void:
	# Inside a TouchScroll the press also reaches the scroll area; once it scrolls, no tap.
	if what == NOTIFICATION_SCROLL_BEGIN:
		_tracking = false


## Selects [param i] without emitting [signal selected] or animating.
func set_index_silently(i: int) -> void:
	index = i
	_slide = float(i)


func _on_skin_changed() -> void:
	_track = null
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
	if mb.pressed:
		_tracking = true
		_press_at = mb.global_position
		return
	# Select on release and only for a tap, so a scroll that starts here changes nothing. Screen
	# positions, because the control moves with the scroll.
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
	_tween.tween_property(self, "_slide", float(i), Design.DUR_BASE)
	if App.instance:
		App.instance.feedback_click()
	selected.emit(i)


func _draw() -> void:
	if options.is_empty():
		return
	var p := Palette.current
	if _track == null:
		_track = Design.surface_box(p.track, size.y * 0.5)
		_knob = Design.surface_box(p.surface_raised, size.y * 0.5 - KNOB_INSET, 1)
	_track.set_corner_radius_all(int(size.y * 0.5))
	_knob.set_corner_radius_all(int(size.y * 0.5 - KNOB_INSET))
	draw_style_box(_track, Rect2(Vector2.ZERO, size))
	var seg_w := size.x / options.size()
	draw_style_box(_knob, Rect2(Vector2(_slide * seg_w + KNOB_INSET, KNOB_INSET),
			Vector2(seg_w - KNOB_INSET * 2.0, size.y - KNOB_INSET * 2.0)))
	for i in options.size():
		var label: String = I18n.t(options[i]) if translate else options[i]
		var fs := Fonts.fit(_font, label, Design.TEXT_CALLOUT, seg_w - Design.SPACE_MD * 2.0)
		var weight := clampf(1.0 - absf(_slide - i), 0.0, 1.0)
		var color := p.text_secondary.lerp(p.text, weight)
		Fonts.draw_centered(self, _font, label, Vector2((i + 0.5) * seg_w, size.y * 0.5), fs, color)
