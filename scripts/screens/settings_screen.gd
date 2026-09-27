class_name SettingsScreen
extends Control
## Sound, music, vibration, theme, language and FPS overlay. Changes apply immediately.

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
var _dividers: Array[ColorRect] = []


func setup(app: App) -> void:
	_app = app


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 30)
	add_child(col)

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
	col.add_child(header)

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
	col.add_child(card2)

	var card3 := Card.make(10, 36)
	card3.add_child(_row("SHOW_FPS", _fps))
	col.add_child(card3)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)

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
	_theme.selected.connect(func(i: int) -> void: _app.set_theme_mode(SaveStore.ThemeMode.LIGHT if i == 0 else SaveStore.ThemeMode.DARK))
	_language.selected.connect(func(i: int) -> void: _app.set_language(I18n.LANGUAGES[i]))


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
	_theme.set_index_silently(0 if s.theme == SaveStore.ThemeMode.LIGHT else 1)
	_language.set_index_silently(I18n.LANGUAGES.find(s.language))


func _on_skin_changed() -> void:
	for d in _dividers:
		d.color = Palette.current.surface_border


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
