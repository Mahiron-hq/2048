class_name PillButton
extends BaseButton
## Rounded button drawn from the palette, with an optional vector icon and a press squash.

enum Look { PRIMARY, SECONDARY, GHOST }

const PRESS_SCALE := 0.045

var look: Look = Look.SECONDARY
var key := ""
var icon: Icons.Kind = Icons.Kind.NONE
var font_size := 30
var height := 84.0
## Icon-only buttons are square.
var icon_only := false

var _press := 0.0:
	set(v):
		_press = v
		queue_redraw()
var _press_tween: Tween
var _style := StyleBoxFlat.new()
var _font: Font


static func make(p_key: String, p_look := Look.SECONDARY, p_icon := Icons.Kind.NONE, p_height := 84.0) -> PillButton:
	var b := PillButton.new()
	b.key = p_key
	b.look = p_look
	b.icon = p_icon
	b.height = p_height
	b.font_size = int(round(p_height * 0.36))
	return b


static func make_icon(p_icon: Icons.Kind, p_height := 76.0) -> PillButton:
	var b := make("", Look.SECONDARY, p_icon, p_height)
	b.icon_only = true
	return b


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_font = Fonts.sans(Fonts.SEMIBOLD)
	button_down.connect(_animate_press.bind(1.0, 0.07))
	button_up.connect(_animate_press.bind(0.0, 0.16))
	mouse_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	pressed.connect(_on_pressed)


func _ready() -> void:
	_update_min_size()
	_on_skin_changed()


func set_key(p_key: String) -> void:
	key = p_key
	_update_min_size()
	queue_redraw()


func _on_language_changed() -> void:
	_update_min_size()
	queue_redraw()


func _on_skin_changed() -> void:
	var p := Palette.current
	_style.set_corner_radius_all(int(height * 0.5))
	_style.corner_detail = 12
	_style.anti_aliasing = true
	_style.border_width_bottom = 0
	_style.set_border_width_all(0)
	_style.shadow_size = 0
	match look:
		Look.PRIMARY:
			_style.bg_color = p.accent
			_style.shadow_color = Color(p.accent, 0.35)
			_style.shadow_size = 10
			_style.shadow_offset = Vector2(0, 4)
		Look.SECONDARY:
			_style.bg_color = p.surface
			_style.border_color = p.surface_border
			_style.set_border_width_all(2)
			_style.shadow_color = p.shadow
			_style.shadow_size = 6
			_style.shadow_offset = Vector2(0, 3)
		Look.GHOST:
			_style.bg_color = Color(p.surface, 0.0)
			_style.border_color = p.surface_border
			_style.set_border_width_all(2)
	queue_redraw()


func _draw() -> void:
	var p := Palette.current
	var s := 1.0 - PRESS_SCALE * _press
	var center := size * 0.5
	draw_set_transform(center * (1.0 - s), 0.0, Vector2(s, s))
	var rect := Rect2(Vector2.ZERO, size)
	var bg := _style.bg_color
	if disabled:
		_style.bg_color = Color(bg, bg.a * 0.45)
	elif _press > 0.0 or is_hovered():
		_style.bg_color = bg.darkened(0.07 * maxf(_press, 0.5)) if not p.dark else bg.lightened(0.06 * maxf(_press, 0.5))
	draw_style_box(_style, rect)
	_style.bg_color = bg

	var fg := p.accent_text if look == Look.PRIMARY else p.text
	if disabled:
		fg = Color(fg, 0.35)
	var icon_size := height * 0.42
	if icon_only:
		Icons.draw(self, icon, center, icon_size, fg)
		draw_set_transform(Vector2.ZERO)
		return
	var label := I18n.t(key)
	var text_w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var gap := height * 0.16
	var total := text_w + (icon_size + gap if icon != Icons.Kind.NONE else 0.0)
	var x := (size.x - total) * 0.5
	if icon != Icons.Kind.NONE:
		Icons.draw(self, icon, Vector2(x + icon_size * 0.5, center.y), icon_size, fg)
		x += icon_size + gap
	var baseline := center.y + font_size * 0.36
	draw_string(_font, Vector2(x, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fg)
	draw_set_transform(Vector2.ZERO)


func _update_min_size() -> void:
	if icon_only:
		custom_minimum_size = Vector2(height, height)
		return
	var w := _font.get_string_size(I18n.t(key), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if icon != Icons.Kind.NONE:
		w += height * 0.58
	custom_minimum_size = Vector2(ceilf(w + height * 0.9), height)


func _animate_press(target: float, duration: float) -> void:
	if _press_tween:
		_press_tween.kill()
	_press_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(self, "_press", target, duration)


func _on_pressed() -> void:
	if App.instance:
		App.instance.feedback_click()
