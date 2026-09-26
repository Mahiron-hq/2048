class_name MenuScreen
extends Control
## Title screen: logo, best score, and entry points into play and settings.

signal new_game_requested
signal continue_requested
signal settings_requested

const LOGO_VALUES := [2, 16, 128, 2048]

var _logo_tiles: Array[TileBadge] = []
var _subtitle := SkinLabel.make("SUBTITLE", 30, Fonts.SEMIBOLD, SkinLabel.Role.MUTED)
var _best_caption := SkinLabel.make("BEST_SCORE", 26, Fonts.SEMIBOLD, SkinLabel.Role.MUTED)
var _best_value := SkinLabel.make("", 64, Fonts.BLACK, SkinLabel.Role.TEXT, true)
var _trophy := _IconView.new()
var _continue := PillButton.make("CONTINUE", PillButton.Look.PRIMARY, Icons.Kind.PLAY, 96)
var _play := PillButton.make("PLAY", PillButton.Look.PRIMARY, Icons.Kind.RESTART, 96)
var _settings := PillButton.make("SETTINGS", PillButton.Look.GHOST, Icons.Kind.GEAR, 96)
var _version := SkinLabel.make("", 22, Fonts.MEDIUM, SkinLabel.Role.MUTED)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	col.add_child(_flex(3))
	var logo := HBoxContainer.new()
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	logo.add_theme_constant_override("separation", 16)
	var digits := "2048"
	for i in 4:
		var t := TileBadge.make(LOGO_VALUES[i], 136, digits[i])
		t.text_ratio = 0.62
		_logo_tiles.append(t)
		logo.add_child(t)
	col.add_child(logo)
	col.add_child(_fixed(28))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_subtitle)
	col.add_child(_flex(2))

	var best_card := Card.make(30, 36)
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
	best_card.add_child(best_row)
	col.add_child(_centered(best_card, 520))
	col.add_child(_flex(2))

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 18)
	buttons.add_child(_continue)
	buttons.add_child(_play)
	buttons.add_child(_settings)
	col.add_child(_centered(buttons, 520))
	col.add_child(_flex(3))
	_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "1.0")
	col.add_child(_version)

	_continue.pressed.connect(func() -> void: continue_requested.emit())
	_play.pressed.connect(func() -> void: new_game_requested.emit())
	_settings.pressed.connect(func() -> void: settings_requested.emit())


## Updates the best score and whether a saved game can be continued.
func refresh(best: int, has_saved_game: bool) -> void:
	_best_value.text = str(best)
	_continue.visible = has_saved_game
	_play.look = PillButton.Look.SECONDARY if has_saved_game else PillButton.Look.PRIMARY
	_play._on_skin_changed()


## Staggered pop-in of the logo tiles; runs once per menu entry.
func play_intro() -> void:
	for i in _logo_tiles.size():
		var t := _logo_tiles[i]
		t.scale = Vector2.ZERO
		t.rotation = -0.25
		var tw := create_tween().set_parallel()
		tw.tween_property(t, "scale", Vector2.ONE, 0.5).set_delay(0.08 + i * 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(t, "rotation", 0.0, 0.5).set_delay(0.08 + i * 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flex(ratio: float) -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = ratio
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _fixed(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _centered(c: Control, width: float) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size.x = width
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
