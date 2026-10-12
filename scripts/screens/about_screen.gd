class_name AboutScreen
extends Control
## Version, author and contacts, credits, and the licenses of everything the app ships with.
## License texts load when their section is opened and are dropped again when it closes or the
## screen is left: kept hidden, hundreds of kilobytes of text were laid out again on every theme,
## language or text size change.

signal back_requested

const EMAIL := "Mahiron.HQ@protonmail.com"
const SOURCE_URL := "https://github.com/Mahiron-hq/2048"
const PRIVACY_URL := "https://mahiron-hq.github.io/2048/privacy/"

## [title key, source]: a res:// text file, or "godot" / "godot_parts" for the engine's own data.
const LICENSES := [
	["LICENSE_GAME", "res://LICENSE"],
	["LICENSE_MUSIC", "res://LICENSE-MUSIC"],
	["LICENSE_FONT", "res://assets/fonts/OFL.txt"],
	["LICENSE_GODOT", "godot"],
	["LICENSE_GODOT_PARTS", "godot_parts"],
	["LICENSE_ANDROID", "res://legal/android-libraries.txt"],
	["LICENSE_RUST", "res://legal/rust-crates.txt"],
]

var _app: App
var _version := SkinLabel.make("", Design.TEXT_BODY, Design.WEIGHT_MEDIUM)
var _column := VBoxContainer.new()
var _header: ScreenHeader
var _sections: Array[_LicenseSection] = []


func setup(app: App) -> void:
	_app = app


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", int(Design.SPACE_LG))
	add_child(root)
	_header = ScreenHeader.make("ABOUT", func() -> void: back_requested.emit())
	root.add_child(_centered(_header))

	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_column.add_theme_constant_override("separation", int(Design.SPACE_MD))
	scroll.add_child(_centered(_column, true))

	var badge := TileBadge.make(2048, Design.CONTROL_LG, "2048")
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title := SkinLabel.make("APP_NAME", Design.TEXT_HEADLINE, Design.WEIGHT_HEAVY)
	var author := _text("ABOUT_AUTHOR")
	for l: Label in [title, _version, author]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(_card([badge, title, _version, author]))

	var mail := PillButton.make("ABOUT_WRITE", PillButton.Look.SECONDARY)
	mail.pressed.connect(func() -> void: OS.shell_open("mailto:" + EMAIL))
	var source := PillButton.make("ABOUT_SOURCE", PillButton.Look.SECONDARY)
	source.pressed.connect(func() -> void: OS.shell_open(SOURCE_URL))
	var privacy := PillButton.make("ABOUT_PRIVACY", PillButton.Look.SECONDARY)
	privacy.pressed.connect(func() -> void: OS.shell_open(PRIVACY_URL))
	var email := _text("")
	email.text = EMAIL
	email.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(_card([mail, email, source, privacy]))

	_column.add_child(_section("ABOUT_THANKS_TITLE"))
	_column.add_child(_card([_text("ABOUT_THANKS")]))

	_column.add_child(_section("ABOUT_LICENSES"))
	var rows: Array = [_text("ABOUT_LICENSES_HINT")]
	for entry in LICENSES:
		var s := _LicenseSection.new()
		s.title_key = entry[0]
		s.source = entry[1]
		_sections.append(s)
		rows.append(s)
	_column.add_child(_card(rows))
	_column.add_child(Modal.gap(Design.SPACE_LG))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_column.custom_minimum_size.x = minf(size.x, Design.COLUMN_MAX)
		_header.custom_minimum_size.x = _column.custom_minimum_size.x
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		for s in _sections:
			s.collapse()


func _on_language_changed() -> void:
	_version.text = I18n.t("ABOUT_VERSION") % ProjectSettings.get_setting("application/config/version", "")


## Updates the version line and closes every open license.
func refresh() -> void:
	_version.text = I18n.t("ABOUT_VERSION") % ProjectSettings.get_setting("application/config/version", "")
	for s in _sections:
		s.collapse()


func _centered(c: Control, fill := false) -> Control:
	var wrap := HBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if fill:
		wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(c)
	return wrap


func _section(key: String) -> Control:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", int(Design.SPACE_LG))
	wrap.add_theme_constant_override("margin_top", int(Design.SPACE_MD))
	wrap.add_child(SkinLabel.caption(key))
	return wrap


func _card(rows: Array) -> Card:
	var card := Card.make(Design.SPACE_LG)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(Design.SPACE_SM))
	for r: Control in rows:
		if r is PillButton:
			r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.fit_text = true
		box.add_child(r)
	card.add_child(box)
	return card


func _text(key: String) -> SkinLabel:
	var l := SkinLabel.make(key, Design.TEXT_CALLOUT, Design.WEIGHT_REGULAR, SkinLabel.Role.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## License texts of the engine: its own MIT license, then every bundled component.
static func godot_text(parts: bool) -> String:
	if not parts:
		return Engine.get_license_text()
	var lines := PackedStringArray()
	for info: Dictionary in Engine.get_copyright_info():
		lines.append(info.name)
		for part: Dictionary in info.parts:
			for holder: String in part.copyright:
				lines.append("  © " + holder)
			lines.append("  " + part.license)
		lines.append("")
	var licenses := Engine.get_license_info()
	for name: String in licenses:
		lines.append("– %s –" % name)
		lines.append(licenses[name])
		lines.append("")
	return "\n".join(lines)


## One license: a tappable title row; the text below loads and shows on the first tap.
class _LicenseSection:
	extends VBoxContainer

	var title_key := ""
	var source := ""
	var _toggle: PillButton
	var _body := SkinLabel.make("", Design.TEXT_CAPTION, Design.WEIGHT_REGULAR, SkinLabel.Role.MUTED)

	func _init() -> void:
		add_theme_constant_override("separation", int(Design.SPACE_XS))
		_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.visible = false

	func _ready() -> void:
		_toggle = PillButton.make(title_key, PillButton.Look.GHOST)
		_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_toggle.fit_text = true
		_toggle.pressed.connect(_flip)
		add_child(_toggle)
		add_child(_body)

	func collapse() -> void:
		_body.visible = false
		_body.text = ""

	func is_open() -> bool:
		return _body.visible

	func _flip() -> void:
		if _body.visible:
			collapse()
			return
		_body.text = _load()
		_body.visible = true

	func _load() -> String:
		match source:
			"godot":
				return AboutScreen.godot_text(false)
			"godot_parts":
				return AboutScreen.godot_text(true)
		var text := FileAccess.get_file_as_string(source)
		return text if not text.is_empty() else I18n.t("LICENSE_MISSING")
