class_name SettingsScreen
extends Control
## App settings (sound, music, vibration, theme, language, FPS overlay and cap) and game settings
## (undo depth). Changes apply immediately.

signal back_requested

var _app: App
var _sound := ToggleSwitch.new()
var _music := ToggleSwitch.new()
var _sound_volume := StepSlider.new()
var _music_volume := StepSlider.new()
var _haptics := ToggleSwitch.new()
var _fps := ToggleSwitch.new()
var _theme := Segmented.make(PackedStringArray(["THEME_LIGHT", "THEME_DARK"]))
var _language := Segmented.make(PackedStringArray([I18n.LANGUAGE_NAMES.ru, I18n.LANGUAGE_NAMES.en]), false)
var _undo := Segmented.make(PackedStringArray(["UNDO_OFF", "1", "2", "3", "4", "5"]))
## Options depend on the display, so they are filled in by [method refresh].
var _fps_limit := Segmented.make(PackedStringArray(["∞"]), false)
## Cap behind each [member _fps_limit] option; 0 means none.
var _fps_limits: Array[int] = [0]
var _dividers: Array[ColorRect] = []
var _columns: Array[Control] = []

const COLUMN_MAX_WIDTH := 760.0


func setup(app: App) -> void:
	_app = app


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 24)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 22)
	var back := PillButton.make_icon(Icons.Kind.BACK, 76)
	back.pressed.connect(func() -> void: back_requested.emit())
	header.add_child(back)
	var title := SkinLabel.make("SETTINGS", 52, Fonts.BLACK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.custom_minimum_size.y = 76
	header.add_child(title)
	root.add_child(_centered(header))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	scroll.add_child(_centered(col, true))

	col.add_child(_section("APP_SETTINGS"))
	var card := Card.make(10, 36)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	card.add_child(rows)
	rows.add_child(_row("SOUND", _sound))
	rows.add_child(_volume_row(_sound_volume))
	rows.add_child(_divider())
	rows.add_child(_row("MUSIC", _music))
	rows.add_child(_volume_row(_music_volume))
	rows.add_child(_divider())
	rows.add_child(_row("HAPTICS", _haptics))
	col.add_child(card)

	var card2 := Card.make(10, 36)
	var rows2 := VBoxContainer.new()
	rows2.add_theme_constant_override("separation", 0)
	card2.add_child(rows2)
	_theme.custom_minimum_size = Vector2(320, 64)
	_language.custom_minimum_size = Vector2(320, 64)
	rows2.add_child(_row("THEME", _theme))
	rows2.add_child(_divider())
	rows2.add_child(_row("LANGUAGE", _language))
	rows2.add_child(_divider())
	rows2.add_child(_row("SHOW_FPS", _fps))
	rows2.add_child(_divider())
	rows2.add_child(_fps_limit_block())
	col.add_child(card2)

	col.add_child(_section("GAME_SETTINGS"))
	var card3 := Card.make(28, 36)
	var undo_box := VBoxContainer.new()
	undo_box.add_theme_constant_override("separation", 8)
	var undo_title := SkinLabel.make("UNDO_LIMIT", 32, Fonts.SEMIBOLD)
	undo_box.add_child(undo_title)
	var undo_hint := SkinLabel.make("UNDO_LIMIT_HINT", 24, Fonts.REGULAR, SkinLabel.Role.MUTED)
	undo_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	undo_box.add_child(undo_hint)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	undo_box.add_child(gap)
	_undo.custom_minimum_size = Vector2(0, 64)
	undo_box.add_child(_undo)
	card3.add_child(undo_box)
	col.add_child(card3)
	var tail := Control.new()
	tail.custom_minimum_size.y = 24
	col.add_child(tail)

	_sound.toggled.connect(func(on: bool) -> void:
		_app.set_sound(on)
		_sound_volume.dimmed = not on)
	_music.toggled.connect(func(on: bool) -> void:
		_app.set_music(on)
		_music_volume.dimmed = not on)
	_sound_volume.changed.connect(func(step: int) -> void: _app.set_sound_volume(step))
	_music_volume.changed.connect(func(step: int) -> void: _app.set_music_volume(step))
	_haptics.toggled.connect(func(on: bool) -> void: _app.set_haptics(on))
	_fps.toggled.connect(func(on: bool) -> void: _app.set_show_fps(on))
	_fps_limit.selected.connect(func(i: int) -> void: _app.set_fps_limit(_fps_limits[i]))
	_theme.selected.connect(func(i: int) -> void: _app.set_theme_mode(SaveStore.ThemeMode.LIGHT if i == 0 else SaveStore.ThemeMode.DARK))
	_language.selected.connect(func(i: int) -> void: _app.set_language(I18n.LANGUAGES[i]))
	_undo.selected.connect(func(i: int) -> void: _app.set_undo_limit(i))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		# One readable column, centered on wide (landscape, tablet) screens.
		var w := minf(size.x, COLUMN_MAX_WIDTH)
		for c in _columns:
			c.custom_minimum_size.x = w


## Syncs controls with the stored settings without triggering their handlers.
func refresh() -> void:
	var s := _app.store
	_sound.set_on_silently(s.sound_on)
	_music.set_on_silently(s.music_on)
	_sound_volume.set_value_silently(s.sound_volume)
	_music_volume.set_value_silently(s.music_volume)
	_sound_volume.dimmed = not s.sound_on
	_music_volume.dimmed = not s.music_on
	_haptics.set_on_silently(s.haptics_on)
	_fps.set_on_silently(s.show_fps)
	_refresh_fps_limits()
	_theme.set_index_silently(0 if s.theme == SaveStore.ThemeMode.LIGHT else 1)
	_language.set_index_silently(I18n.LANGUAGES.find(s.language))
	_undo.set_index_silently(s.undo_limit)


## Offers only the caps this display can show evenly; a stored cap it cannot is dropped.
func _refresh_fps_limits() -> void:
	_fps_limits = DisplayRate.limit_options()
	var labels := PackedStringArray()
	for limit in _fps_limits:
		labels.append(str(limit) if limit > 0 else "∞")
	_fps_limit.options = labels
	if not _fps_limits.has(_app.store.fps_limit):
		_app.set_fps_limit(0)
	_fps_limit.set_index_silently(_fps_limits.find(_app.store.fps_limit))
	_fps_limit.queue_redraw()


func _on_skin_changed() -> void:
	for d in _dividers:
		d.color = Palette.current.surface_border


## Wraps [param c] so it stays a centered column no wider than COLUMN_MAX_WIDTH.
func _centered(c: Control, fill := false) -> Control:
	var wrap := HBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if fill:
		wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(c)
	_columns.append(c)
	return wrap


func _section(key: String) -> Control:
	var label := SkinLabel.make(key, 26, Fonts.BOLD, SkinLabel.Role.MUTED)
	label.custom_minimum_size.y = 40
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return label


func _row(key: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 104
	row.add_theme_constant_override("separation", 16)
	var pad_l := Control.new()
	pad_l.custom_minimum_size.x = 18
	row.add_child(pad_l)
	var label := SkinLabel.make(key, 32, Fonts.SEMIBOLD)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	row.add_child(label)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	var pad_r := Control.new()
	pad_r.custom_minimum_size.x = 14
	row.add_child(pad_r)
	return row


## Frame cap: title, hint, then the cap selector across the card.
func _fps_limit_block() -> Control:
	# Same insets as the label and control of a _row (padding plus row separation).
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 34)
	wrap.add_theme_constant_override("margin_right", 30)
	wrap.add_theme_constant_override("margin_top", 22)
	wrap.add_theme_constant_override("margin_bottom", 18)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(SkinLabel.make("FPS_LIMIT", 32, Fonts.SEMIBOLD))
	var hint := SkinLabel.make("FPS_LIMIT_HINT", 24, Fonts.REGULAR, SkinLabel.Role.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	box.add_child(gap)
	_fps_limit.custom_minimum_size = Vector2(0, 64)
	box.add_child(_fps_limit)
	wrap.add_child(box)
	return wrap


## Volume slider line under a toggle row: quiet speaker, slider, loud speaker.
func _volume_row(slider: StepSlider) -> Control:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 18)
	wrap.add_theme_constant_override("margin_right", 14)
	wrap.add_theme_constant_override("margin_bottom", 16)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_Glyph.make(Icons.Kind.SPEAKER_LOW))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	row.add_child(_Glyph.make(Icons.Kind.SPEAKER_HIGH))
	wrap.add_child(row)
	return wrap


func _divider() -> Control:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 22)
	wrap.add_theme_constant_override("margin_right", 22)
	var line := ColorRect.new()
	line.custom_minimum_size.y = 2
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dividers.append(line)
	wrap.add_child(line)
	return wrap


## Muted vector glyph beside a slider.
class _Glyph:
	extends Control

	var kind: Icons.Kind = Icons.Kind.NONE

	static func make(p_kind: Icons.Kind) -> _Glyph:
		var g := _Glyph.new()
		g.kind = p_kind
		g.custom_minimum_size = Vector2(44, 56)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return g

	func _on_skin_changed() -> void:
		queue_redraw()

	func _draw() -> void:
		Icons.draw(self, kind, size * 0.5, 34.0, Palette.current.text_muted)
