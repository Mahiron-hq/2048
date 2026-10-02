class_name ToggleSwitch
extends BaseButton
## On/off switch with a sliding knob.

const KNOB_INSET := 5.0

var _t := 0.0:
	set(v):
		_t = v
		queue_redraw()
var _tween: Tween
var _box := StyleBoxFlat.new()


func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Design.SWITCH_SIZE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggled.connect(_on_toggled)


## Sets the state without emitting [signal BaseButton.toggled] or animating.
func set_on_silently(on: bool) -> void:
	set_pressed_no_signal(on)
	_t = 1.0 if on else 0.0


func _on_skin_changed() -> void:
	queue_redraw()


func _on_toggled(on: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_t", 1.0 if on else 0.0, Design.DUR_BASE)
	if App.instance:
		App.instance.feedback_click()


func _draw() -> void:
	var p := Palette.current
	var track := Design.SWITCH_SIZE
	var origin := (size - track) * 0.5
	var r := track.y * 0.5
	_box.bg_color = p.track.lerp(p.accent, clampf(_t, 0.0, 1.0))
	_box.set_corner_radius_all(int(r))
	_box.corner_detail = 12
	_box.anti_aliasing = true
	draw_style_box(_box, Rect2(origin, track))
	var knob_r := r - KNOB_INSET
	var c := Vector2(lerpf(origin.x + r, origin.x + track.x - r, _t), origin.y + r)
	draw_circle(c + Vector2(0, 1.5), knob_r, Color(p.shadow, p.shadow.a * 2.0), true, -1.0, true)
	draw_circle(c, knob_r, Color.WHITE if not p.dark else p.text, true, -1.0, true)
