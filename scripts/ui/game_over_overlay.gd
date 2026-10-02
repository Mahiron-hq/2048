class_name GameOverOverlay
extends Modal
## End-of-game summary: final score, best tile, move count and record badge.

signal restart_requested
signal menu_requested

const STAT_TILE := Design.CONTROL_LG

var _title := SkinLabel.make("GAME_OVER", Design.TEXT_HEADLINE, Design.WEIGHT_HEAVY)
var _record := _RecordBadge.new()
var _score := SkinLabel.make("", Design.TEXT_DISPLAY, Design.WEIGHT_HEAVY, SkinLabel.Role.TEXT, true)
var _score_caption := SkinLabel.caption("FINAL_SCORE")
var _tile := TileBadge.make(2, STAT_TILE)
var _tile_caption := SkinLabel.caption("BEST_TILE")
var _moves := SkinLabel.make("", Design.TEXT_TITLE, Design.WEIGHT_HEAVY, SkinLabel.Role.TEXT, true)
var _moves_caption := SkinLabel.caption("MOVES")
var _again := PillButton.make("TRY_AGAIN", PillButton.Look.PRIMARY, Icons.Kind.RESTART)
var _menu := PillButton.make("MENU", PillButton.Look.SECONDARY, Icons.Kind.MENU)
var _shown_score := 0.0:
	set(v):
		_shown_score = v
		_score.text = I18n.number(int(round(v)))


func _init() -> void:
	super._init()
	body.add_theme_constant_override("separation", int(Design.SPACE_XS))
	for l in [_title, _score, _score_caption, _tile_caption, _moves_caption, _moves]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_title)
	body.add_child(_centered(_record))
	body.add_child(Modal.gap(Design.SPACE_XS))
	body.add_child(_score_caption)
	body.add_child(_score)

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", int(Design.SPACE_2XL))
	var tile_col := VBoxContainer.new()
	tile_col.add_theme_constant_override("separation", int(Design.SPACE_SM))
	tile_col.add_child(_tile_caption)
	tile_col.add_child(_centered(_tile))
	var moves_col := VBoxContainer.new()
	moves_col.add_theme_constant_override("separation", int(Design.SPACE_SM))
	_moves.custom_minimum_size.y = STAT_TILE
	_moves.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	moves_col.add_child(_moves_caption)
	moves_col.add_child(_moves)
	stats.add_child(tile_col)
	stats.add_child(moves_col)
	body.add_child(Modal.gap(Design.SPACE_MD))
	body.add_child(stats)
	body.add_child(Modal.gap(Design.SPACE_XL))
	body.add_child(Modal.button_row([_menu, _again]))
	_again.pressed.connect(func() -> void: restart_requested.emit())
	_menu.pressed.connect(func() -> void: menu_requested.emit())


func present(score: int, best_tile: int, moves: int, record: bool) -> void:
	_tile.value = best_tile
	_moves.text = I18n.number(moves)
	_record.visible = record
	_shown_score = 0.0
	open()
	_fit_score_font(score)
	var tw := create_tween()
	tw.tween_interval(Design.DUR_BASE)
	tw.tween_property(self, "_shown_score", float(score), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tile.scale = Vector2.ZERO
	tw.parallel().tween_property(_tile, "scale", Vector2.ONE, Design.DUR_SLOW).set_delay(Design.DUR_SLOW) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Caches every digit at the score and move-count sizes, plus the record badge.
func prime() -> void:
	_score.text = "0123456789 "
	_moves.text = "0123456789 "
	_record.visible = true
	super.prime()


## Shrinks the score font so the final value fits the card; counting up must not widen it.
func _fit_score_font(score: int) -> void:
	var font := _score.get_theme_font("font")
	var room := _card.custom_minimum_size.x - 2.0 * _card.padding
	var fs := Fonts.fit(font, I18n.number(score), Design.TEXT_DISPLAY, room, Design.TEXT_HEADLINE)
	_score.add_theme_font_size_override("font_size", fs)


static func _centered(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c)
	return cc


## Accent pill reading "New record!".
class _RecordBadge:
	extends Control

	var _font: Font = Fonts.sans(Design.WEIGHT_BOLD)
	var _box: StyleBoxFlat

	func _init() -> void:
		custom_minimum_size = Vector2(0, Design.CONTROL_SM * 0.75)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_on_language_changed()

	func _on_language_changed() -> void:
		var w := _font.get_string_size(I18n.t("NEW_RECORD"), HORIZONTAL_ALIGNMENT_LEFT, -1, Design.TEXT_CALLOUT).x
		custom_minimum_size.x = w + Design.ICON_SM + Design.SPACE_XS + Design.SPACE_LG * 2.0
		queue_redraw()

	func _on_skin_changed() -> void:
		_box = null
		queue_redraw()

	func _draw() -> void:
		var p := Palette.current
		if _box == null:
			_box = Design.surface_box(p.accent_soft, size.y * 0.5)
		draw_style_box(_box, Rect2(Vector2.ZERO, size))
		var x := Design.SPACE_LG
		Icons.draw(self, Icons.Kind.TROPHY, Vector2(x + Design.ICON_SM * 0.5, size.y * 0.5), Design.ICON_SM, p.accent)
		draw_string(_font, Vector2(x + Design.ICON_SM + Design.SPACE_XS, Fonts.baseline(size.y * 0.5, Design.TEXT_CALLOUT)),
				I18n.t("NEW_RECORD"), HORIZONTAL_ALIGNMENT_LEFT, -1, Design.TEXT_CALLOUT, p.accent)
