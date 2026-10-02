class_name SettingsScreen
extends Control
## App and game settings; changes apply at once. Switches end their row, selectors span the card
## under their title.

signal back_requested

var _app: App
var _sound := ToggleSwitch.new()
var _music := ToggleSwitch.new()
var _sound_volume := StepSlider.new()
var _music_volume := StepSlider.new()
var _haptics := ToggleSwitch.new()
var _hints := ToggleSwitch.new()
var _fps := ToggleSwitch.new()
var _theme := Segmented.make(PackedStringArray(["THEME_SYSTEM", "THEME_LIGHT", "THEME_DARK"]))
var _language := Segmented.make(PackedStringArray([I18n.LANGUAGE_NAMES.ru, I18n.LANGUAGE_NAMES.en]), false)
var _quality := Segmented.make(PackedStringArray(["QUALITY_LOW", "QUALITY_MEDIUM", "QUALITY_HIGH"]))
var _quality_hint := SkinLabel.make("QUALITY_HINT", Design.TEXT_CALLOUT, Design.WEIGHT_REGULAR, SkinLabel.Role.MUTED)
var _undo := Segmented.make(PackedStringArray(["UNDO_OFF", "1", "2", "3", "4", "5"]))
## Options depend on the display, so they are filled in by [method refresh].
var _fps_limit := Segmented.make(PackedStringArray(["∞"]), false)
## Cap behind each [member _fps_limit] option; 0 means none.
var _fps_limits: Array[int] = [0]
var _dividers: Array[ColorRect] = []
var _columns: Array[Control] = []


func setup(app: App) -> void:
	_app = app


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", int(Design.SPACE_LG))
	add_child(root)
	root.add_child(_centered(ScreenHeader.make("SETTINGS", func() -> void: back_requested.emit())))

	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(Design.SPACE_MD))
	scroll.add_child(_centered(col, true))

	col.add_child(_section("APP_SETTINGS"))
	col.add_child(_card([
		_row("SOUND", _sound), _volume_row(_sound_volume), _divider(),
		_row("MUSIC", _music), _volume_row(_music_volume), _divider(),
		_row("HAPTICS", _haptics),
	]))
	_quality_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_card([
		_block("THEME", null, _theme), _divider(),
		_block("LANGUAGE", null, _language), _divider(),
		_block("QUALITY", _quality_hint, _quality), _divider(),
		_row("SHOW_FPS", _fps), _divider(),
		_block("FPS_LIMIT", _note("FPS_LIMIT_HINT"), _fps_limit),
	]))

	col.add_child(_section("GAME_SETTINGS"))
	col.add_child(_card([
		_row("HINTS", _hints), _note_row("HINTS_HINT"), _divider(),
		_block("UNDO_LIMIT", _note("UNDO_LIMIT_HINT"), _undo),
	]))
	col.add_child(Modal.gap(Design.SPACE_LG))

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
	_hints.toggled.connect(func(on: bool) -> void: _app.set_hints(on))
	_fps_limit.selected.connect(func(i: int) -> void: _app.set_fps_limit(_fps_limits[i]))
	_theme.selected.connect(func(i: int) -> void: _app.set_theme_mode(i as SaveStore.ThemeMode))
	_language.selected.connect(func(i: int) -> void: _app.set_language(I18n.LANGUAGES[i]))
	_quality.selected.connect(func(i: int) -> void:
		_app.set_quality(i as SaveStore.Quality)
		_refresh_quality_hint())
	_undo.selected.connect(func(i: int) -> void: _app.set_undo_limit(i))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		# One readable column, centered on wide (landscape, tablet) screens.
		var w := minf(size.x, Design.COLUMN_MAX)
		for c in _columns:
			c.custom_minimum_size.x = w
		if _app:
			_refresh_quality_hint.call_deferred()


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
	_hints.set_on_silently(s.hints_on)
	_refresh_fps_limits()
	_theme.set_index_silently(s.theme)
	_language.set_index_silently(I18n.LANGUAGES.find(s.language))
	_quality.set_index_silently(s.quality)
	_refresh_quality_hint()
	_undo.set_index_silently(s.undo_limit)


func _on_language_changed() -> void:
	_refresh_quality_hint()


func _refresh_quality_hint() -> void:
	if _app == null:
		return
	var px := _app.render_resolution()
	_quality_hint.set_key("QUALITY_HINT", "%d × %d" % [px.x, px.y])


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
		d.color = Palette.current.outline


## Wraps [param c] so it stays a centered column no wider than Design.COLUMN_MAX.
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
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", int(Design.SPACE_LG))
	wrap.add_theme_constant_override("margin_top", int(Design.SPACE_MD))
	wrap.add_child(SkinLabel.caption(key))
	return wrap


func _card(rows: Array) -> Card:
	var card := Card.make(Design.SPACE_LG)
	card.padding_v = Design.SPACE_XS
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	for r: Control in rows:
		box.add_child(r)
	card.add_child(box)
	return card


## Label on the left, [param control] at the end of the row.
func _row(key: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = Design.ROW_HEIGHT
	row.add_theme_constant_override("separation", int(Design.SPACE_MD))
	var label := SkinLabel.make(key, Design.TEXT_BODY, Design.WEIGHT_MEDIUM)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	row.add_child(label)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	return row


## Title, optional note, then [param control] across the card.
func _block(key: String, note: Control, control: Control) -> Control:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", int(Design.SPACE_LG))
	wrap.add_theme_constant_override("margin_bottom", int(Design.SPACE_LG))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(Design.SPACE_XS))
	box.add_child(SkinLabel.make(key, Design.TEXT_BODY, Design.WEIGHT_MEDIUM))
	if note:
		box.add_child(note)
	box.add_child(Modal.gap(Design.SPACE_XS))
	control.custom_minimum_size = Vector2(0, Design.CONTROL_SM)
	box.add_child(control)
	wrap.add_child(box)
	return wrap


func _note(key: String) -> SkinLabel:
	var l := SkinLabel.make(key, Design.TEXT_CALLOUT, Design.WEIGHT_REGULAR, SkinLabel.Role.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Note under a switch row, ending the row's block.
func _note_row(key: String) -> Control:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_bottom", int(Design.SPACE_LG))
	wrap.add_theme_constant_override("margin_right", int(Design.SWITCH_SIZE.x + Design.SPACE_MD))
	wrap.add_child(_note(key))
	return wrap


## Volume slider line under a switch row: quiet speaker, slider, loud speaker.
func _volume_row(slider: StepSlider) -> Control:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_bottom", int(Design.SPACE_MD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(Design.SPACE_SM))
	row.add_child(_Glyph.make(Icons.Kind.SPEAKER_LOW))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	row.add_child(_Glyph.make(Icons.Kind.SPEAKER_HIGH))
	wrap.add_child(row)
	return wrap


func _divider() -> Control:
	var line := ColorRect.new()
	line.custom_minimum_size.y = Design.HAIRLINE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.color = Palette.current.outline
	_dividers.append(line)
	return line


## Secondary line icon beside a slider.
class _Glyph:
	extends Control

	var kind: Icons.Kind = Icons.Kind.NONE

	static func make(p_kind: Icons.Kind) -> _Glyph:
		var g := _Glyph.new()
		g.kind = p_kind
		g.custom_minimum_size = Vector2(Design.ICON_MD, Design.CONTROL_SM)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return g

	func _on_skin_changed() -> void:
		queue_redraw()

	func _draw() -> void:
		Icons.draw(self, kind, size * 0.5, Design.ICON_MD, Palette.current.text_secondary)
