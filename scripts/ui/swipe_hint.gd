class_name SwipeHint
extends Control
## Translucent veil over the whole board with four pulsing arrows: the board is played by
## swiping. It dims the tiles slightly without hiding them and lets every touch through.

## Area of the board inside the parent, set by [BoardView] on layout.
var board_rect := Rect2():
	set(v):
		board_rect = v
		queue_redraw()
## Corner radius of the board, so the veil matches its shape.
var board_radius := 24.0

var _pulse := 0.0:
	set(v):
		_pulse = v
		queue_redraw()
var _tween: Tween
var _pulse_tween: Tween
var _box := StyleBoxFlat.new()
var _font: Font = Fonts.sans(Fonts.SEMIBOLD)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0


func _on_language_changed() -> void:
	queue_redraw()


## Fades in; the arrows keep pulsing until the hint is dismissed by the first move.
func appear() -> void:
	if _tween:
		_tween.kill()
	if _pulse_tween:
		_pulse_tween.kill()
	show()
	_pulse = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "_pulse", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "_pulse", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Fades out; no-op when already hidden.
func dismiss(instant := false) -> void:
	if not visible:
		return
	if _tween:
		_tween.kill()
	if instant:
		_stop_pulse()
		modulate.a = 0.0
		hide()
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(_stop_pulse)
	_tween.tween_callback(hide)


func is_showing() -> bool:
	return visible and modulate.a > 0.0


func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null


func _draw() -> void:
	if board_rect.size.x <= 0.0:
		return
	_box.bg_color = Color(0.05, 0.04, 0.08, 0.32)
	_box.set_corner_radius_all(int(board_radius))
	_box.corner_detail = 12
	draw_style_box(_box, board_rect)

	# Arrow geometry is sized from a central square, independent of the veil.
	var side := board_rect.size.x * 0.64
	var fs := int(side * 0.058)
	var caption := I18n.t("SWIPE_TO_PLAY")
	var max_w := board_rect.size.x * 0.86
	while fs > 10 and _font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		fs -= 1
	var c := board_rect.get_center() - Vector2(0, fs * 0.8)
	var ink := Color(1, 1, 1, 0.92)
	var reach := side * (0.26 + 0.05 * _pulse)
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
	var baseline := minf(c.y + side * 0.45, board_rect.end.y - fs)
	draw_string(_font, Vector2(board_rect.get_center().x - cw * 0.5, baseline), caption,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.88))
