class_name SkinLabel
extends Label
## Label that follows the active palette and language.

enum Role { TEXT, MUTED, ACCENT, ON_ACCENT, FAINT }

var role: Role = Role.TEXT
## Translation key; when empty, [member text] is used verbatim.
var key := ""
## Optional value substituted into the translated string with %.
var arg: Variant = null


## [param p_size] and [param p_weight] come from the Design type scale.
static func make(p_key: String, p_size: int, p_weight := Design.WEIGHT_REGULAR, p_role := Role.TEXT, tabular := false) -> SkinLabel:
	var l := SkinLabel.new()
	l.key = p_key
	l.role = p_role
	l.add_theme_font_override("font", Fonts.sans(p_weight, tabular))
	l.add_theme_font_size_override("font_size", p_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l._refresh_text()
	l._on_skin_changed()
	return l


## Caption style: small capitals in the secondary color.
static func caption(p_key: String) -> SkinLabel:
	var l := make(p_key, Design.TEXT_CAPTION, Design.WEIGHT_BOLD, Role.MUTED)
	l.uppercase = true
	l.add_theme_font_override("font", Fonts.sans(Design.WEIGHT_BOLD, false, Design.CAPTION_TRACKING))
	return l


func set_key(p_key: String, p_arg: Variant = null) -> void:
	key = p_key
	arg = p_arg
	_refresh_text()


func _on_language_changed() -> void:
	_refresh_text()


func _on_skin_changed() -> void:
	var p := Palette.current
	var c: Color
	match role:
		Role.MUTED:
			c = p.text_secondary
		Role.FAINT:
			c = p.text_tertiary
		Role.ACCENT:
			c = p.accent
		Role.ON_ACCENT:
			c = p.on_accent
		_:
			c = p.text
	add_theme_color_override("font_color", c)


func _refresh_text() -> void:
	if key.is_empty():
		return
	var s := I18n.t(key)
	text = s % arg if arg != null else s
