class_name ToggleSwitch
extends BaseButton
## iOS/Material-style on/off switch with an animated knob.

const TRACK := Vector2(88, 50)

var _t := 0.0:
	set(v):
		_t = v
		queue_redraw()
var _tween: Tween
var _box := StyleBoxFlat.new()


func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = TRACK
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
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_t", 1.0 if on else 0.0, 0.22)
	if App.instance:
		App.instance.feedback_click()


func _draw() -> void:
	var p := Palette.current
	var origin := (size - TRACK) * 0.5
	var r := TRACK.y * 0.5
	var off := p.surface_border if not p.dark else p.surface_pressed.lightened(0.08)
	var track_color := off.lerp(p.accent, clampf(_t, 0.0, 1.0))
	var box := _box
	box.bg_color = track_color
	box.set_corner_radius_all(int(r))
	box.corner_detail = 12
	draw_style_box(box, Rect2(origin, TRACK))
	var knob_r := r - 5.0
	var x := lerpf(origin.x + r, origin.x + TRACK.x - r, _t)
	var c := Vector2(x, origin.y + r)
	draw_circle(c + Vector2(0, 2), knob_r, Color(0, 0, 0, 0.18), true, -1.0, true)
	draw_circle(c, knob_r, Color.WHITE, true, -1.0, true)
