class_name ScoreBox
extends Control
## Caption over a number on a surface panel. The number counts smoothly, gains float up as "+N",
## and a new record lights the panel with the accent for a moment.

const COUNT_TIME := 0.3
const GAIN_TIME := 0.6
const FLASH_TIME := 0.9

var caption_key := ""
var value := 0

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
var _box: StyleBoxFlat
var _ring: StyleBoxFlat
var _caption_font: Font = Fonts.sans(Design.WEIGHT_BOLD, false, Design.CAPTION_TRACKING)
var _value_font: Font = Fonts.sans(Design.WEIGHT_HEAVY, true)
var _popups: Array[Label] = []


static func make(p_caption_key: String) -> ScoreBox:
	var b := ScoreBox.new()
	b.caption_key = p_caption_key
	return b


func _init() -> void:
	custom_minimum_size = Vector2(Design.CONTROL_LG * 1.6, Design.CONTROL_LG)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows [param v]. With [param animate], counts from the current value (up or down).
func set_value(v: int, animate := true) -> void:
	if _count_tween:
		_count_tween.kill()
	value = v
	if not animate:
		_shown = v
		return
	_count_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_count_tween.tween_property(self, "_shown", float(v), COUNT_TIME)


## Floats "+[param amount]" up from below the box.
func pop_gain(amount: int) -> void:
	var l := _take_popup()
	l.text = "+%d" % amount
	l.add_theme_color_override("font_color", Palette.current.accent)
	l.size = Vector2(size.x, Design.SPACE_XL)
	l.position = Vector2(0, size.y + Design.SPACE_MD)
	l.modulate.a = 1.0
	l.visible = true
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", size.y - Design.SPACE_XS, GAIN_TIME)
	tw.tween_property(l, "modulate:a", 0.0, GAIN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.hide)


## Accent outline that fades, used when the best score is beaten.
func flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "_flash", 0.0, FLASH_TIME).set_trans(Tween.TRANS_SINE)


func _on_skin_changed() -> void:
	var p := Palette.current
	_box = Design.surface_box(p.surface, Design.RADIUS_LG, 1)
	_ring = Design.surface_box(Color(p.accent, 0.0), Design.RADIUS_LG)
	_ring.border_color = p.accent
	_ring.set_border_width_all(Design.HAIRLINE + 1)
	queue_redraw()


func _on_language_changed() -> void:
	queue_redraw()


func _draw() -> void:
	if _box == null:
		_on_skin_changed()
	var p := Palette.current
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_box, rect)
	if _flash > 0.0:
		_ring.border_color = Color(p.accent, _flash)
		draw_style_box(_ring, rect)
	var room := size.x - Design.SPACE_MD * 2.0
	var cap := I18n.t(caption_key).to_upper()
	var cap_size := Fonts.fit(_caption_font, cap, Design.TEXT_CAPTION, room)
	var cap_color := p.text_secondary.lerp(p.accent, _flash)
	Fonts.draw_centered(self, _caption_font, cap, Vector2(size.x * 0.5, size.y * 0.3), cap_size, cap_color)
	var txt := I18n.number(int(round(_shown)))
	var fs := Fonts.fit(_value_font, txt, Design.TEXT_HEADLINE, room, Design.TEXT_CAPTION)
	Fonts.draw_centered(self, _value_font, txt, Vector2(size.x * 0.5, size.y * 0.66), fs, p.text)


func _take_popup() -> Label:
	for l in _popups:
		if not l.visible:
			return l
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Fonts.sans(Design.WEIGHT_HEAVY, true))
	l.add_theme_font_size_override("font_size", Design.TEXT_CALLOUT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 5
	add_child(l)
	_popups.append(l)
	return l
