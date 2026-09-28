class_name MenuScreen
extends Control
## Title screen: logo, best score for the chosen board size, and entry points into play,
## statistics and settings. Portrait stacks everything; landscape splits into two columns.

signal new_game_requested
signal continue_requested
signal settings_requested
signal stats_requested
## The board-size button was pressed; the listener opens the picker next to [param anchor].
signal size_menu_requested(anchor: Rect2)

const LOGO_VALUES := [2, 16, 128, 2048]
const COLUMN_WIDTH := 540.0

var _logo_tiles: Array[TileBadge] = []
var _subtitle := SkinLabel.make("SUBTITLE", 30, Fonts.SEMIBOLD, SkinLabel.Role.MUTED)
var _best_caption := SkinLabel.make("", 26, Fonts.SEMIBOLD, SkinLabel.Role.MUTED)
var _best_value := SkinLabel.make("", 64, Fonts.BLACK, SkinLabel.Role.TEXT, true)
var _trophy := _IconView.new()
var _continue := PillButton.make("CONTINUE", PillButton.Look.PRIMARY, Icons.Kind.PLAY, 96)
var _size := PillButton.make("", PillButton.Look.SECONDARY, Icons.Kind.GRID, 96)
var _play := PillButton.make("PLAY", PillButton.Look.PRIMARY, Icons.Kind.RESTART, 96)
var _stats := PillButton.make("STATS", PillButton.Look.GHOST, Icons.Kind.CHART, 96)
var _settings := PillButton.make("SETTINGS", PillButton.Look.GHOST, Icons.Kind.GEAR, 96)
var _version := SkinLabel.make("", 22, Fonts.MEDIUM, SkinLabel.Role.MUTED)

var _brand := VBoxContainer.new()
var _best_card := Card.make(30, 36)
var _buttons := VBoxContainer.new()
var _portrait := VBoxContainer.new()
var _landscape := HBoxContainer.new()
var _left := VBoxContainer.new()
var _landscape_mode := false
var _saved_size := 0
var _selected_size := Board.DEFAULT_SIZE


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var logo := HBoxContainer.new()
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	logo.add_theme_constant_override("separation", 16)
	var digits := "2048"
	for i in 4:
		var t := TileBadge.make(LOGO_VALUES[i], 136, digits[i])
		t.text_ratio = 0.62
		_logo_tiles.append(t)
		logo.add_child(t)
	_brand.add_theme_constant_override("separation", 28)
	_brand.add_child(logo)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brand.add_child(_subtitle)

	var best_row := HBoxContainer.new()
	best_row.add_theme_constant_override("separation", 26)
	best_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_trophy.custom_minimum_size = Vector2(84, 84)
	best_row.add_child(_trophy)
	var best_col := VBoxContainer.new()
	best_col.add_theme_constant_override("separation", 0)
	best_col.add_child(_best_caption)
	best_col.add_child(_best_value)
	best_row.add_child(best_col)
	_best_card.add_child(best_row)
	_best_card.custom_minimum_size.x = COLUMN_WIDTH

	_buttons.add_theme_constant_override("separation", 18)
	_buttons.custom_minimum_size.x = COLUMN_WIDTH
	_buttons.add_child(_continue)
	var play_row := HBoxContainer.new()
	play_row.add_theme_constant_override("separation", 14)
	# Size picker takes about a quarter of the row, the play button the rest.
	_size.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_size.size_flags_stretch_ratio = 1.0
	_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play.size_flags_stretch_ratio = 3.0
	play_row.add_child(_size)
	play_row.add_child(_play)
	_buttons.add_child(play_row)
	_buttons.add_child(_stats)
	_buttons.add_child(_settings)

	_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "1.0")

	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait.add_theme_constant_override("separation", 0)
	add_child(_portrait)
	_landscape.set_anchors_preset(Control.PRESET_FULL_RECT)
	_landscape.alignment = BoxContainer.ALIGNMENT_CENTER
	_landscape.add_theme_constant_override("separation", 72)
	_landscape.visible = false
	add_child(_landscape)
	_left.alignment = BoxContainer.ALIGNMENT_CENTER
	_left.add_theme_constant_override("separation", 48)
	_apply_layout(false)

	_continue.pressed.connect(func() -> void: continue_requested.emit())
	_play.pressed.connect(func() -> void: new_game_requested.emit())
	_stats.pressed.connect(func() -> void: stats_requested.emit())
	_settings.pressed.connect(func() -> void: settings_requested.emit())
	_size.pressed.connect(func() -> void: size_menu_requested.emit(_size.get_global_rect()))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var wide := size.x > size.y * 1.1
		if wide != _landscape_mode:
			_apply_layout(wide)


## Updates the best score, the chosen board size and the Continue button.
func refresh(best: int, selected_size: int, saved_size: int) -> void:
	_selected_size = selected_size
	_saved_size = saved_size
	_best_value.text = I18n.number(best)
	_size.text_override = I18n.grid(selected_size)
	_continue.visible = saved_size > 0
	_play.look = PillButton.Look.SECONDARY if saved_size > 0 else PillButton.Look.PRIMARY
	_play._on_skin_changed()
	_refresh_labels()


func _on_language_changed() -> void:
	_refresh_labels()


func _refresh_labels() -> void:
	_best_caption.text = "%s · %s" % [I18n.t("BEST_SCORE"), I18n.grid(_selected_size)]
	_continue.text_override = "%s · %s" % [I18n.t("CONTINUE"), I18n.grid(_saved_size)] if _saved_size > 0 else ""


## Staggered pop-in of the logo tiles; runs once per menu entry.
func play_intro() -> void:
	for i in _logo_tiles.size():
		var t := _logo_tiles[i]
		t.scale = Vector2.ZERO
		t.rotation = -0.25
		var tw := create_tween().set_parallel()
		tw.tween_property(t, "scale", Vector2.ONE, 0.5).set_delay(0.08 + i * 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(t, "rotation", 0.0, 0.5).set_delay(0.08 + i * 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _apply_layout(wide: bool) -> void:
	_landscape_mode = wide
	# Two columns share one short screen: a slightly smaller logo leaves room for wide fonts.
	var tile := 116.0 if wide else 136.0
	for t in _logo_tiles:
		t.custom_minimum_size = Vector2(tile, tile)
	for node: Control in [_brand, _best_card, _buttons, _version]:
		var parent := node.get_parent()
		if parent:
			parent.remove_child(node)
	for c: Node in _portrait.get_children() + _left.get_children() + _landscape.get_children():
		if c != _left:
			c.get_parent().remove_child(c)
			c.queue_free()
	if _left.get_parent():
		_left.get_parent().remove_child(_left)
	if wide:
		_left.add_child(_brand)
		_left.add_child(_centered(_best_card))
		_landscape.add_child(_left)
		var right := VBoxContainer.new()
		right.alignment = BoxContainer.ALIGNMENT_CENTER
		right.add_theme_constant_override("separation", 24)
		right.add_child(_buttons)
		right.add_child(_version)
		_landscape.add_child(right)
	else:
		_portrait.add_child(_flex(3))
		_portrait.add_child(_brand)
		_portrait.add_child(_flex(2))
		_portrait.add_child(_centered(_best_card))
		_portrait.add_child(_flex(2))
		_portrait.add_child(_centered(_buttons))
		_portrait.add_child(_flex(3))
		_portrait.add_child(_version)
	_portrait.visible = not wide
	_landscape.visible = wide


func _flex(ratio: float) -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = ratio
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _centered(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c)
	return cc


class _IconView:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _on_skin_changed() -> void:
		queue_redraw()

	func _draw() -> void:
		var p := Palette.current
		draw_circle(size * 0.5, size.x * 0.5, Color(p.accent, 0.15), true, -1.0, true)
		Icons.draw(self, Icons.Kind.TROPHY, size * 0.5, size.x * 0.52, p.accent)
