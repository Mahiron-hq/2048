class_name StatsScreen
extends Control
## Lifetime statistics, overall or for one board size.

signal back_requested

const FILTERS := [0, 3, 4, 5, 6]

var _app: App
var _filter := Segmented.new()
var _grid := GridContainer.new()
var _empty := SkinLabel.make("NO_GAMES", 26, Fonts.MEDIUM, SkinLabel.Role.MUTED)
var _cards := {}
var _tile := TileBadge.make(2, 86)
var _column := VBoxContainer.new()

const COLUMN_MAX_WIDTH := 1200.0


func setup(app: App) -> void:
	_app = app


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := HBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)
	var col := _column
	col.add_theme_constant_override("separation", 28)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 22)
	var back := PillButton.make_icon(Icons.Kind.BACK, 76)
	back.pressed.connect(func() -> void: back_requested.emit())
	header.add_child(back)
	var title := SkinLabel.make("STATS", 52, Fonts.BLACK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.custom_minimum_size.y = 76
	header.add_child(title)
	col.add_child(header)

	var labels := PackedStringArray(["STATS_ALL"])
	for n in FILTERS.slice(1):
		labels.append(I18n.grid(n))
	_filter.options = labels
	_filter.custom_minimum_size = Vector2(0, 64)
	_filter.selected.connect(func(_i: int) -> void: refresh())
	col.add_child(_filter)

	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 20)
	scroll.add_child(inner)
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 18)
	inner.add_child(_grid)
	for key in ["GAMES_PLAYED", "AVERAGE_SCORE", "BEST_TILE", "BEST_SCORE", "TOTAL_MOVES", "PLAY_TIME"]:
		var card := _StatCard.new()
		card.caption_key = key
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(card)
		_cards[key] = card
	_tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_cards.BEST_TILE.set_extra(_tile)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_empty)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_column.custom_minimum_size.x = minf(size.x, COLUMN_MAX_WIDTH)
		_grid.columns = 3 if size.x > size.y * 1.1 else 2


func _on_language_changed() -> void:
	refresh()


## Re-reads the numbers from the store for the selected filter.
func refresh() -> void:
	if _app == null:
		return
	# Include the game in progress so time and moves are current.
	_app.flush_play_time()
	var st := _app.store.stats_for(FILTERS[_filter.index])
	_cards.GAMES_PLAYED.set_value(I18n.number(st.games))
	_cards.AVERAGE_SCORE.set_value(I18n.number(st.average_score))
	_cards.BEST_SCORE.set_value(I18n.number(st.best_score))
	_cards.TOTAL_MOVES.set_value(I18n.number(st.moves))
	_cards.PLAY_TIME.set_value(I18n.duration(st.time))
	_cards.BEST_TILE.set_value("" if st.best_tile > 0 else "—")
	_tile.visible = st.best_tile > 0
	if st.best_tile > 0:
		_tile.value = st.best_tile
		_tile.label = ""
	_empty.visible = st.games == 0


## One statistic: caption on top, big value (or a custom node such as a tile) below.
class _StatCard:
	extends Card

	var caption_key := ""
	var _caption: SkinLabel
	var _value := SkinLabel.make("", 46, Fonts.BLACK, SkinLabel.Role.TEXT, true)
	var _box := VBoxContainer.new()

	func _init() -> void:
		padding = 26
		radius = 30
		custom_minimum_size = Vector2(0, 176)
		_box.add_theme_constant_override("separation", 10)
		_box.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(_box)
		_value.clip_text = true

	func _ready() -> void:
		super._ready()
		_caption = SkinLabel.make(caption_key, 24, Fonts.SEMIBOLD, SkinLabel.Role.MUTED)
		_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(_caption)
		_box.move_child(_caption, 0)
		_box.add_child(_value)

	func set_value(text: String) -> void:
		_value.text = text
		_value.visible = not text.is_empty()

	func set_extra(node: Control) -> void:
		_box.add_child(node)
