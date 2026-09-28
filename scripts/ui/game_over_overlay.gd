class_name GameOverOverlay
extends Modal
## End-of-game summary: final score, best tile, move count and record badge.

signal restart_requested
signal menu_requested

const SCORE_FONT_SIZE := 104

var _title := SkinLabel.make("GAME_OVER", 44, Fonts.BOLD)
var _record := _RecordBadge.new()
var _score := SkinLabel.make("", SCORE_FONT_SIZE, Fonts.BLACK, SkinLabel.Role.TEXT, true)
var _score_caption := SkinLabel.make("FINAL_SCORE", 24, Fonts.BOLD, SkinLabel.Role.MUTED)
var _tile := TileBadge.make(2, 92)
var _tile_caption := SkinLabel.make("BEST_TILE", 22, Fonts.MEDIUM, SkinLabel.Role.MUTED)
var _moves := SkinLabel.make("", 52, Fonts.BLACK, SkinLabel.Role.TEXT, true)
var _moves_caption := SkinLabel.make("MOVES", 22, Fonts.MEDIUM, SkinLabel.Role.MUTED)
var _again := PillButton.make("TRY_AGAIN", PillButton.Look.PRIMARY, Icons.Kind.RESTART)
var _menu := PillButton.make("MENU", PillButton.Look.SECONDARY, Icons.Kind.MENU)
var _shown_score := 0.0:
	set(v):
		_shown_score = v
		_score.text = str(int(round(v)))


func _init() -> void:
	super._init()
	body.add_theme_constant_override("separation", 10)
	for l in [_title, _score, _score_caption, _tile_caption, _moves_caption, _moves]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_title)
	body.add_child(_centered(_record))
	body.add_child(_score)
	body.add_child(_score_caption)

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 56)
	var tile_col := VBoxContainer.new()
	tile_col.add_theme_constant_override("separation", 8)
	tile_col.add_child(_centered(_tile))
	tile_col.add_child(_tile_caption)
	var moves_col := VBoxContainer.new()
	moves_col.add_theme_constant_override("separation", 8)
	_moves.custom_minimum_size.y = 92
	_moves.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	moves_col.add_child(_moves)
	moves_col.add_child(_moves_caption)
	stats.add_child(tile_col)
	stats.add_child(moves_col)
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	body.add_child(gap)
	body.add_child(stats)
	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 26
	body.add_child(gap2)
	body.add_child(Modal.button_row([_menu, _again]))
	_again.pressed.connect(func() -> void: restart_requested.emit())
	_menu.pressed.connect(func() -> void: menu_requested.emit())


func present(score: int, best_tile: int, moves: int, record: bool) -> void:
	_tile.value = best_tile
	_moves.text = str(moves)
	_record.visible = record
	_shown_score = 0.0
	open()
	_fit_score_font(score)
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(self, "_shown_score", float(score), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tile.scale = Vector2.ZERO
	tw.parallel().tween_property(_tile, "scale", Vector2.ONE, 0.45).set_delay(0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Caches every digit at the score and move-count sizes, plus the record badge.
func prime() -> void:
	_score.text = "0123456789"
	_moves.text = "0123456789"
	_record.visible = true
	super.prime()


## Shrinks the score font so the final value fits the card; counting up must not widen it.
func _fit_score_font(score: int) -> void:
	var font := _score.get_theme_font("font")
	var room := _card.custom_minimum_size.x - 2.0 * _card.padding
	var fs := SCORE_FONT_SIZE
	while fs > 40 and font.get_string_size(str(score), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 4
	_score.add_theme_font_size_override("font_size", fs)


static func _centered(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c)
	return cc


## Accent pill reading "New record!".
class _RecordBadge:
	extends Control

	var _font: Font = Fonts.sans(Fonts.BOLD)
	var _box := StyleBoxFlat.new()

	func _init() -> void:
		custom_minimum_size = Vector2(0, 52)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_on_language_changed()

	func _on_language_changed() -> void:
		var w := _font.get_string_size(I18n.t("NEW_RECORD"), HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		custom_minimum_size.x = w + 88
		queue_redraw()

	func _on_skin_changed() -> void:
		queue_redraw()

	func _draw() -> void:
		var p := Palette.current
		_box.bg_color = Color(p.accent, 0.16)
		_box.border_color = p.accent
		_box.set_border_width_all(2)
		_box.set_corner_radius_all(26)
		_box.corner_detail = 10
		draw_style_box(_box, Rect2(Vector2.ZERO, size))
		Icons.draw(self, Icons.Kind.TROPHY, Vector2(34, size.y * 0.5), 26, p.accent)
		draw_string(_font, Vector2(56, size.y * 0.5 + 26 * 0.36), I18n.t("NEW_RECORD"), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, p.accent)
