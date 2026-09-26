class_name ScoreBox
extends Control
## Caption + number panel. The number counts up smoothly and gains float up as "+N".

var caption_key := ""
var value := 0
var highlight := false:
	set(v):
		highlight = v
		queue_redraw()

var _shown := 0.0:
	set(v):
		_shown = v
		queue_redraw()
var _count_tween: Tween
var _flash := 0.0:
	set(v):
		_flash = v
		queue_redraw()
var _flash_tween: Tween
var _box := StyleBoxFlat.new()
var _caption_font: Font = Fonts.sans(Fonts.BOLD)
var _value_font: Font = Fonts.sans(Fonts.BLACK, true)
var _popups: Array[Label] = []


static func make(p_caption_key: String) -> ScoreBox:
	var b := ScoreBox.new()
	b.caption_key = p_caption_key
	return b


func _init() -> void:
	custom_minimum_size = Vector2(150, 96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows [param v]. With [param animate], counts up from the current value.
func set_value(v: int, animate := true) -> void:
	if _count_tween:
		_count_tween.kill()
	value = v
	if not animate or v < _shown:
		_shown = v
		return
	_count_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_count_tween.tween_property(self, "_shown", float(v), 0.35)


## Floats "+[param amount]" up from the box.
func pop_gain(amount: int) -> void:
	var l := _take_popup()
	l.text = "+%d" % amount
	l.add_theme_color_override("font_color", Palette.current.accent)
	l.size = Vector2(size.x, 40)
	l.position = Vector2(0, size.y + 22.0)
	l.modulate.a = 1.0
	l.visible = true
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", size.y - 16.0, 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.hide)


## Brief glow, used when the best score is beaten.
func flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "_flash", 0.0, 0.8).set_trans(Tween.TRANS_SINE)


func _on_skin_changed() -> void:
	queue_redraw()


func _on_language_changed() -> void:
	queue_redraw()


func _draw() -> void:
	var p := Palette.current
	_box.bg_color = p.board if not highlight else p.board.lerp(p.accent, 0.18)
	_box.set_corner_radius_all(24)
	_box.corner_detail = 10
	if _flash > 0.0:
		_box.shadow_color = Color(p.accent, 0.55 * _flash)
		_box.shadow_size = int(16 * _flash)
	else:
		_box.shadow_size = 0
	draw_style_box(_box, Rect2(Vector2.ZERO, size))
	var cap := I18n.t(caption_key).to_upper()
	var cap_size := 20
	var cw := _caption_font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, cap_size).x
	draw_string(_caption_font, Vector2((size.x - cw) * 0.5, size.y * 0.33), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, cap_size, p.text_muted)
	var txt := str(int(round(_shown)))
	var fs := 40
	var w := _value_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while w > size.x - 20 and fs > 18:
		fs -= 2
		w = _value_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_value_font, Vector2((size.x - w) * 0.5, size.y * 0.78), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, p.text)


func _take_popup() -> Label:
	for l in _popups:
		if not l.visible:
			return l
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Fonts.sans(Fonts.BLACK, true))
	l.add_theme_font_size_override("font_size", 30)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 5
	add_child(l)
	_popups.append(l)
	return l
