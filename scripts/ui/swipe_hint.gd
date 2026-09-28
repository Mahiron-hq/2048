class_name SwipeHint
extends Control
## Translucent card over the board with four arrows: the board is played by swiping.
## It dims the tiles slightly without hiding them and lets every touch through.

const PULSES := 3

## Area of the board inside the parent, set by [BoardView] on layout.
var board_rect := Rect2():
	set(v):
		board_rect = v
		queue_redraw()

var _pulse := 0.0:
	set(v):
		_pulse = v
		queue_redraw()
var _tween: Tween
var _box := StyleBoxFlat.new()
var _font: Font = Fonts.sans(Fonts.SEMIBOLD)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0


func _on_language_changed() -> void:
	queue_redraw()


## Fades in and pulses the arrows a few times, then holds still so the screen can idle.
func appear() -> void:
	if _tween:
		_tween.kill()
	show()
	_pulse = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	for i in PULSES:
		_tween.tween_property(self, "_pulse", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "_pulse", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Fades out; no-op when already hidden.
func dismiss(instant := false) -> void:
	if not visible:
		return
	if _tween:
		_tween.kill()
	if instant:
		modulate.a = 0.0
		hide()
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(hide)


func is_showing() -> bool:
	return visible and modulate.a > 0.0


func _draw() -> void:
	if board_rect.size.x <= 0.0:
		return
	var side := board_rect.size.x * 0.64
	var panel := Rect2(board_rect.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))
	_box.bg_color = Color(0.05, 0.04, 0.08, 0.3)
	_box.border_color = Color(1, 1, 1, 0.12)
	_box.set_border_width_all(2)
	_box.set_corner_radius_all(int(side * 0.12))
	_box.corner_detail = 12
	draw_style_box(_box, panel)

	var fs := int(side * 0.058)
	var caption := I18n.t("SWIPE_TO_PLAY")
	var max_w := side * 0.86
	while fs > 10 and _font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		fs -= 1
	var caption_h := fs * 1.6
	var c := panel.get_center() - Vector2(0, caption_h * 0.5)
	var ink := Color(1, 1, 1, 0.92)
	var reach := side * (0.26 + 0.035 * _pulse)
	var arrow := side * 0.1
	var width := maxf(3.0, side * 0.026)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var tip: Vector2 = c + d * reach
		var back: Vector2 = -d * arrow
		var pts := PackedVector2Array([tip + back + back.orthogonal() * 0.9, tip, tip + back - back.orthogonal() * 0.9])
		draw_polyline(pts, ink, width, true)
		for p in pts:
			draw_circle(p, width * 0.5, ink, true, -1.0, true)
		draw_line(c + d * side * 0.07, tip + back * 0.35, Color(ink, 0.45), width * 0.7, true)
	draw_circle(c, side * 0.045, Color(ink, 0.35), true, -1.0, true)
	draw_arc(c, side * 0.045, 0.0, TAU, 24, ink, width * 0.6, true)

	var cw := _font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, Vector2(panel.get_center().x - cw * 0.5, panel.end.y - side * 0.09), caption,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))
