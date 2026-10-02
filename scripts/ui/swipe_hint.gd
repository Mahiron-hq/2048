class_name SwipeHint
extends Control
## Light veil over the board with four breathing chevrons and a caption: the board is played by
## swiping. The tiles stay visible and every touch passes through.

## Area of the board inside the parent, set by [BoardView] on layout.
var board_rect := Rect2():
	set(v):
		board_rect = v
		queue_redraw()
## Corner radius of the board, so the veil matches its shape.
var board_radius := Design.RADIUS_LG

var _pulse := 0.0:
	set(v):
		_pulse = v
		queue_redraw()
var _tween: Tween
var _pulse_tween: Tween
var _box := StyleBoxFlat.new()
var _font: Font = Fonts.sans(Design.WEIGHT_BOLD)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0


func _on_language_changed() -> void:
	queue_redraw()


func _on_skin_changed() -> void:
	queue_redraw()


## Fades in; the chevrons keep breathing until the hint is dismissed by the first move.
func appear() -> void:
	if _tween:
		_tween.kill()
	if _pulse_tween:
		_pulse_tween.kill()
	show()
	_pulse = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, Design.DUR_SLOW).set_trans(Tween.TRANS_SINE)
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "_pulse", 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "_pulse", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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
	_tween.tween_property(self, "modulate:a", 0.0, Design.DUR_BASE).set_trans(Tween.TRANS_SINE)
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
	var p := Palette.current
	_box.bg_color = Color(p.scrim, p.scrim.a * 0.75)
	_box.set_corner_radius_all(int(board_radius))
	_box.corner_detail = 12
	_box.anti_aliasing = true
	draw_style_box(_box, board_rect)

	var side := board_rect.size.x * 0.6
	var caption := I18n.t("SWIPE_TO_PLAY")
	var fs := Fonts.fit(_font, caption, Design.TEXT_BODY, board_rect.size.x - Design.SPACE_2XL * 2.0)
	var c := board_rect.get_center() - Vector2(0, fs)
	var ink := p.overlay_ink
	var reach := side * (0.24 + 0.04 * _pulse)
	var w := maxf(3.0, side * 0.024)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var tip: Vector2 = c + d * reach
		var back: Vector2 = -d * side * 0.08
		var pts := PackedVector2Array([tip + back + back.orthogonal(), tip, tip + back - back.orthogonal()])
		draw_polyline(pts, Color(ink, 0.5 + 0.4 * _pulse), w, true)
		for q in pts:
			draw_circle(q, w * Icons.CAP, Color(ink, 0.5 + 0.4 * _pulse), true, -1.0, true)
	draw_arc(c, side * 0.05, 0.0, TAU, 32, Color(ink, 0.9), w * 0.8, true)
	Fonts.draw_centered(self, _font, caption, Vector2(board_rect.get_center().x, minf(c.y + side * 0.46, board_rect.end.y - fs * 1.5)), fs, ink)
