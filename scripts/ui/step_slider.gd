class_name StepSlider
extends Control
## Discrete slider with [member steps] positions (1..steps); tap or drag, the knob snaps and glides.

signal changed(value: int)

const KNOB_RADIUS := 17.0
const TRACK_WIDTH := 8.0
const TICK_RADIUS := 3.5

var steps := 5
var value := 5
## Drawn faded while the feature it controls is switched off; still adjustable.
var dimmed := false:
	set(v):
		dimmed = v
		modulate.a = 0.45 if v else 1.0

var _pos := 4.0:
	set(v):
		_pos = v
		queue_redraw()
var _tween: Tween
var _dragging := false


func _init() -> void:
	custom_minimum_size = Vector2(220, 56)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Sets [param v] without emitting [signal changed] or animating.
func set_value_silently(v: int) -> void:
	value = clampi(v, 1, steps)
	_pos = value - 1


func _on_skin_changed() -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		_dragging = mb.pressed
		if mb.pressed:
			_pick(mb.position.x)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_pick(event.position.x)
		accept_event()


func _pick(x: float) -> void:
	var usable := maxf(size.x - KNOB_RADIUS * 2.0, 1.0)
	var index := clampi(roundi((x - KNOB_RADIUS) / usable * (steps - 1)), 0, steps - 1)
	if index + 1 == value:
		return
	value = index + 1
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_pos", float(index), 0.14)
	changed.emit(value)


func _draw() -> void:
	var p := Palette.current
	var y := size.y * 0.5
	var x0 := KNOB_RADIUS
	var x1 := size.x - KNOB_RADIUS
	var knob_x := lerpf(x0, x1, _pos / float(steps - 1))
	var off := p.surface_border if not p.dark else p.surface_pressed.lightened(0.08)
	_capsule(x0, x1, y, off)
	_capsule(x0, knob_x, y, p.accent)
	for i in steps:
		var tx := lerpf(x0, x1, i / float(steps - 1))
		var on := tx <= knob_x + 0.5
		draw_circle(Vector2(tx, y), TICK_RADIUS, Color(p.accent_text, 0.85) if on else p.text_muted, true, -1.0, true)
	draw_circle(Vector2(knob_x, y + 2.0), KNOB_RADIUS, Color(0, 0, 0, 0.18), true, -1.0, true)
	draw_circle(Vector2(knob_x, y), KNOB_RADIUS, Color.WHITE, true, -1.0, true)
	draw_arc(Vector2(knob_x, y), KNOB_RADIUS - 1.0, 0.0, TAU, 32, Color(p.accent, 0.45), 2.0, true)
	draw_circle(Vector2(knob_x, y), KNOB_RADIUS * 0.34, p.accent, true, -1.0, true)


func _capsule(a: float, b: float, y: float, color: Color) -> void:
	if b > a:
		draw_line(Vector2(a, y), Vector2(b, y), color, TRACK_WIDTH, true)
	draw_circle(Vector2(a, y), TRACK_WIDTH * 0.5, color, true, -1.0, true)
	draw_circle(Vector2(b, y), TRACK_WIDTH * 0.5, color, true, -1.0, true)
