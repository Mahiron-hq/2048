class_name SkinLabel
extends Label
## Label that follows the active palette and language.

enum Role { TEXT, MUTED, ACCENT, ON_ACCENT }

var role: Role = Role.TEXT
## Translation key; when empty, [member text] is used verbatim.
var key := ""
## Optional value substituted into the translated string with %.
var arg: Variant = null


static func make(p_key: String, p_size: int, p_weight := Fonts.MEDIUM, p_role := Role.TEXT, tabular := false) -> SkinLabel:
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
			c = p.text_muted
		Role.ACCENT:
			c = p.accent
		Role.ON_ACCENT:
			c = p.accent_text
		_:
			c = p.text
	add_theme_color_override("font_color", c)


func _refresh_text() -> void:
	if key.is_empty():
		return
	var s := I18n.t(key)
	text = s % arg if arg != null else s
