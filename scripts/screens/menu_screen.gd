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

## Four steps of the tile climb, so the logo reads as one progression.
const LOGO_VALUES := [8, 32, 512, 2048]
const LOGO_TILE := 128.0
const LOGO_TILE_LANDSCAPE := 112.0
## Every block lines up with the four logo tiles.
const COLUMN_WIDTH := LOGO_TILE * 4.0 + Design.SPACE_MD * 3.0
const TROPHY_DISC := Design.CONTROL_SM

var _logo_tiles: Array[TileBadge] = []
var _logo := HBoxContainer.new()
var _subtitle := SkinLabel.make("SUBTITLE", Design.TEXT_CALLOUT, Design.WEIGHT_MEDIUM, SkinLabel.Role.MUTED)
var _best_caption := SkinLabel.caption("")
var _best_value := SkinLabel.make("", Design.TEXT_TITLE, Design.WEIGHT_HEAVY, SkinLabel.Role.TEXT, true)
var _trophy := _TrophyDisc.new()
var _continue := PillButton.make("CONTINUE", PillButton.Look.PRIMARY, Icons.Kind.PLAY, Design.CONTROL_LG)
var _size := PillButton.make("", PillButton.Look.SECONDARY, Icons.Kind.GRID, Design.CONTROL_LG)
var _play := PillButton.make("PLAY", PillButton.Look.PRIMARY, Icons.Kind.RESTART, Design.CONTROL_LG)
var _stats := PillButton.make("STATS", PillButton.Look.GHOST, Icons.Kind.CHART)
var _settings := PillButton.make("SETTINGS", PillButton.Look.GHOST, Icons.Kind.GEAR)
var _version := SkinLabel.make("", Design.TEXT_CAPTION, Design.WEIGHT_MEDIUM, SkinLabel.Role.FAINT)

var _brand := VBoxContainer.new()
var _best_card := Card.make(Design.SPACE_LG, Design.RADIUS_XL)
var _buttons := VBoxContainer.new()
var _portrait := VBoxContainer.new()
var _landscape := HBoxContainer.new()
var _left := VBoxContainer.new()
var _landscape_mode := false
var _saved_size := 0
var _selected_size := Board.DEFAULT_SIZE


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_logo.alignment = BoxContainer.ALIGNMENT_CENTER
	_logo.add_theme_constant_override("separation", int(Design.SPACE_MD))
	var digits := "2048"
	for i in 4:
		var t := TileBadge.make(LOGO_VALUES[i], LOGO_TILE, digits[i])
		t.text_ratio = 0.6
		_logo_tiles.append(t)
		_logo.add_child(t)
	_brand.add_theme_constant_override("separation", int(Design.SPACE_LG))
	_brand.add_child(_logo)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brand.add_child(_subtitle)

	var best_row := HBoxContainer.new()
	best_row.add_theme_constant_override("separation", int(Design.SPACE_LG))
	_trophy.custom_minimum_size = Vector2(TROPHY_DISC, TROPHY_DISC)
	_trophy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	best_row.add_child(_trophy)
	var best_col := VBoxContainer.new()
	best_col.add_theme_constant_override("separation", int(Design.SPACE_2XS))
	best_col.alignment = BoxContainer.ALIGNMENT_CENTER
	best_col.add_child(_best_caption)
	best_col.add_child(_best_value)
	best_row.add_child(best_col)
	_best_card.add_child(best_row)
	_best_card.custom_minimum_size.x = COLUMN_WIDTH

	_buttons.add_theme_constant_override("separation", int(Design.SPACE_SM))
	_buttons.custom_minimum_size.x = COLUMN_WIDTH
	_buttons.add_child(_continue)
	_buttons.add_child(_row([_size, _play], [1.0, 2.4]))
	_buttons.add_child(_row([_stats, _settings], [1.0, 1.0]))

	_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "1.0")

	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait.add_theme_constant_override("separation", 0)
	add_child(_portrait)
	_landscape.set_anchors_preset(Control.PRESET_FULL_RECT)
	_landscape.alignment = BoxContainer.ALIGNMENT_CENTER
	_landscape.add_theme_constant_override("separation", int(Design.SPACE_3XL))
	_landscape.visible = false
	add_child(_landscape)
	_left.alignment = BoxContainer.ALIGNMENT_CENTER
	_left.add_theme_constant_override("separation", int(Design.SPACE_2XL))
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
	# One main action at a time: Continue when a game is waiting, otherwise New game.
	_play.look = PillButton.Look.SECONDARY if saved_size > 0 else PillButton.Look.PRIMARY
	_play._on_skin_changed()
	_refresh_labels()


func _on_language_changed() -> void:
	_refresh_labels()


func _refresh_labels() -> void:
	_best_caption.text = "%s · %s" % [I18n.t("BEST_SCORE"), I18n.grid(_selected_size)]
	_continue.text_override = "%s · %s" % [I18n.t("CONTINUE"), I18n.grid(_saved_size)] if _saved_size > 0 else ""


## Staggered entry of the logo tiles; runs once per menu entry.
func play_intro() -> void:
	for i in _logo_tiles.size():
		var t := _logo_tiles[i]
		t.scale = Vector2.ZERO
		var tw := create_tween()
		tw.tween_property(t, "scale", Vector2.ONE, Design.DUR_SLOW * 1.4).set_delay(Design.DUR_INSTANT + i * Design.DUR_INSTANT) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _apply_layout(wide: bool) -> void:
	_landscape_mode = wide
	# Two columns share one short screen: a smaller logo leaves room for wide fonts.
	var tile := LOGO_TILE_LANDSCAPE if wide else LOGO_TILE
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
		right.add_theme_constant_override("separation", int(Design.SPACE_LG))
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
		_portrait.add_child(_flex(2))
		_portrait.add_child(_version)
	_portrait.visible = not wide
	_landscape.visible = wide


static func _row(buttons: Array, ratios: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(Design.SPACE_SM))
	for i in buttons.size():
		var b: Control = buttons[i]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = ratios[i]
		row.add_child(b)
	return row


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


## Trophy on a soft accent disc beside the best score.
class _TrophyDisc:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _on_skin_changed() -> void:
		queue_redraw()

	func _draw() -> void:
		var p := Palette.current
		draw_circle(size * 0.5, size.x * 0.5, p.accent_soft, true, -1.0, true)
		Icons.draw(self, Icons.Kind.TROPHY, size * 0.5, Design.ICON_MD, p.accent)
