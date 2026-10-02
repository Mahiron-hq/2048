class_name PillButton
extends BaseButton
## Pill-shaped button with an optional line icon; round when it has only an icon.

## PRIMARY: the screen's main action, in the accent. SECONDARY: raised neutral. GHOST: outline
## only, for quiet actions.
enum Look { PRIMARY, SECONDARY, GHOST }

var look: Look = Look.SECONDARY
var key := ""
var icon: Icons.Kind = Icons.Kind.NONE
var font_size := Design.TEXT_BODY
var height := Design.CONTROL_MD
## Icon-only buttons are circles.
var icon_only := false:
	set(v):
		icon_only = v
		_update_min_size()
		queue_redraw()
## Shown verbatim instead of the translation of [member key] when not empty.
var text_override := "":
	set(v):
		text_override = v
		if is_inside_tree():
			_update_min_size()
		queue_redraw()
## Tighter padding and the smaller label size, for rows that must fit a narrow column.
var compact := false:
	set(v):
		compact = v
		font_size = Design.TEXT_CALLOUT if v else Design.TEXT_BODY
		_update_min_size()
		queue_redraw()
## Leaves the icon out of a labeled button when room is short.
var hide_icon := false:
	set(v):
		hide_icon = v
		_update_min_size()
		queue_redraw()
## Small count bubble on the top-right corner; hidden when 0 or less.
var badge := 0:
	set(v):
		badge = v
		queue_redraw()
## Calls attention to the button, 0 (none) to 1: an accent ring and tint.
var glow := 0.0:
	set(v):
		glow = v
		queue_redraw()

var _press := 0.0:
	set(v):
		_press = v
		queue_redraw()
var _press_tween: Tween
var _box := StyleBoxFlat.new()
var _ring := StyleBoxFlat.new()
var _font: Font


static func make(p_key: String, p_look := Look.SECONDARY, p_icon := Icons.Kind.NONE, p_height := Design.CONTROL_MD) -> PillButton:
	var b := PillButton.new()
	b.key = p_key
	b.look = p_look
	b.icon = p_icon
	b.height = p_height
	return b


static func make_icon(p_icon: Icons.Kind, p_height := Design.CONTROL_MD) -> PillButton:
	var b := make("", Look.SECONDARY, p_icon, p_height)
	b.icon_only = true
	return b


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_font = Fonts.sans(Design.WEIGHT_BOLD)
	button_down.connect(_animate_press.bind(1.0, Design.DUR_INSTANT))
	button_up.connect(_animate_press.bind(0.0, Design.DUR_FAST))
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
	match look:
		Look.PRIMARY:
			_box = Design.surface_box(p.accent, height * 0.5)
		Look.SECONDARY:
			_box = Design.surface_box(p.surface_raised, height * 0.5, 1)
		Look.GHOST:
			_box = Design.surface_box(Color(p.surface_raised, 0.0), height * 0.5)
			_box.border_color = p.outline
			_box.set_border_width_all(Design.HAIRLINE)
	_ring = Design.surface_box(Color(p.accent, 0.0), height * 0.5)
	_ring.border_color = p.accent
	_ring.set_border_width_all(Design.HAIRLINE + 1)
	queue_redraw()


func _draw() -> void:
	var p := Palette.current
	var s := 1.0 - Design.PRESS_SCALE * _press
	var center := size * 0.5
	draw_set_transform(center * (1.0 - s), 0.0, Vector2(s, s))
	var rect := Rect2(Vector2.ZERO, size)
	var bg := _box.bg_color
	if disabled:
		_box.bg_color = Color(bg, bg.a * 0.5)
	elif look == Look.PRIMARY:
		_box.bg_color = bg.lerp(p.accent_pressed, maxf(_press, 0.5 if is_hovered() else 0.0))
	elif _press > 0.0 or is_hovered():
		var tint := p.text if look == Look.GHOST else p.track
		_box.bg_color = bg.lerp(Color(tint, 0.12 if look == Look.GHOST else 1.0), 0.6 * maxf(_press, 0.4))
	if glow > 0.0 and not disabled:
		_box.bg_color = _box.bg_color.lerp(p.accent_soft.blend(p.surface_raised), glow)
	draw_style_box(_box, rect)
	_box.bg_color = bg
	if glow > 0.0 and not disabled:
		_ring.border_color = Color(p.accent, glow)
		draw_style_box(_ring, rect)

	var fg := p.on_accent if look == Look.PRIMARY else p.text
	if disabled:
		fg = p.text_tertiary if look != Look.PRIMARY else Color(fg, 0.6)
	elif glow > 0.0:
		fg = fg.lerp(p.accent, glow)
	var icon_size := Design.ICON_MD if height >= Design.CONTROL_MD else Design.ICON_SM
	if icon_only:
		Icons.draw(self, icon, center, icon_size, fg)
	else:
		var label := _label()
		var text_w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var gap := Design.SPACE_SM
		var with_icon := icon != Icons.Kind.NONE and not hide_icon
		var total := text_w + (icon_size + gap if with_icon else 0.0)
		var x := (size.x - total) * 0.5
		if with_icon:
			Icons.draw(self, icon, Vector2(x + icon_size * 0.5, center.y), icon_size, fg)
			x += icon_size + gap
		draw_string(_font, Vector2(x, Fonts.baseline(center.y, font_size)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fg)
	if badge > 0 and not disabled:
		var r := Design.SPACE_MD
		var c := Vector2(size.x - r * 0.75, r * 0.75)
		draw_circle(c, r + Design.HAIRLINE, p.bg, true, -1.0, true)
		draw_circle(c, r, p.accent, true, -1.0, true)
		Fonts.draw_centered(self, _font, str(badge), c, Design.TEXT_CAPTION, p.on_accent)
	draw_set_transform(Vector2.ZERO)


func _label() -> String:
	return text_override if not text_override.is_empty() else I18n.t(key)


func _update_min_size() -> void:
	if _font == null:
		return
	if icon_only:
		custom_minimum_size = Vector2(height, height)
		return
	var w := _font.get_string_size(_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if icon != Icons.Kind.NONE and not hide_icon:
		w += Design.ICON_MD + Design.SPACE_SM
	var side := Design.SPACE_LG if compact else Design.SPACE_XL
	custom_minimum_size = Vector2(ceilf(w + side * 2.0), height)


func _animate_press(target: float, duration: float) -> void:
	if _press_tween:
		_press_tween.kill()
	_press_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(self, "_press", target, duration)


func _on_pressed() -> void:
	if App.instance:
		App.instance.feedback_click()
