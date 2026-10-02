class_name SizePicker
extends Control
## Small popover listing the board sizes, anchored to the button that opened it.
## A tap outside the card closes it.

signal chosen(size: int)

const ROW_HEIGHT := Design.CONTROL_MD
const MIN_WIDTH := Design.CONTROL_LG * 3.0
const INSET := Design.SPACE_XS

var is_open := false

var _card := Card.make(INSET, Design.RADIUS_LG, 2)
var _list := VBoxContainer.new()
var _tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_card.raised = true
	_list.add_theme_constant_override("separation", int(Design.SPACE_2XS))
	_card.add_child(_list)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	# Rows are built once; reopening only moves the check mark, so the card never measures
	# rows that are still waiting to be freed.
	for n in range(Board.MIN_SIZE, Board.MAX_SIZE + 1):
		var row := _Row.new()
		row.grid = n
		row.pressed.connect(_choose.bind(n))
		_list.add_child(row)


## Opens next to [param anchor] (global rect) with [param current] marked.
func open_at(anchor: Rect2, current: int) -> void:
	var width := maxf(anchor.size.x, MIN_WIDTH)
	for row: _Row in _list.get_children():
		row.selected = row.grid == current
		row.custom_minimum_size = Vector2(width - INSET * 2.0, ROW_HEIGHT)
		row.queue_redraw()
	is_open = true
	show()
	_card.modulate.a = 0.0
	_card.size = Vector2.ZERO
	var card_size := _card.get_combined_minimum_size()
	_card.size = card_size
	var local := get_global_transform().affine_inverse() * anchor.position
	var area := get_rect().size
	var space_above := local.y - Design.SPACE_SM
	var space_below := area.y - (local.y + anchor.size.y + Design.SPACE_SM)
	var above := space_above >= card_size.y or space_above >= space_below
	var y := local.y - card_size.y - Design.SPACE_SM if above else local.y + anchor.size.y + Design.SPACE_SM
	y = clampf(y, Design.SPACE_XS, maxf(Design.SPACE_XS, area.y - card_size.y - Design.SPACE_XS))
	var x := clampf(local.x, Design.SPACE_XS, maxf(Design.SPACE_XS, area.x - card_size.x - Design.SPACE_XS))
	_card.position = Vector2(x, y)
	# Short landscape screens: shrink the card rather than let it leave the screen.
	var fit := minf(1.0, (area.y - Design.SPACE_MD) / card_size.y)
	_card.pivot_offset = Vector2(card_size.x * 0.2, card_size.y if above else 0.0)
	if fit < 1.0:
		_card.position.y = Design.SPACE_XS
		_card.pivot_offset = Vector2(card_size.x * 0.2, 0.0)
	_card.scale = Vector2(0.94, 0.94) * fit
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_card, "modulate:a", 1.0, Design.DUR_FAST)
	_tween.tween_property(_card, "scale", Vector2(fit, fit), Design.DUR_BASE)


func close() -> void:
	if not is_open:
		return
	is_open = false
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_card, "modulate:a", 0.0, Design.DUR_FAST)
	_tween.tween_property(_card, "scale", Vector2(0.96, 0.96), Design.DUR_FAST)
	_tween.chain().tween_callback(hide)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		close()


func _choose(n: int) -> void:
	close()
	chosen.emit(n)


## One size option: a miniature N×N grid, its label and a check mark when current.
class _Row:
	extends BaseButton

	var grid := 4
	var selected := false
	var _font: Font = Fonts.sans(Design.WEIGHT_BOLD)
	var _box := StyleBoxFlat.new()

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		pressed.connect(func() -> void:
			if App.instance:
				App.instance.feedback_click())

	func _draw() -> void:
		var p := Palette.current
		if selected or is_hovered() or button_pressed:
			_box = Design.surface_box(p.accent_soft if selected else p.track, Design.RADIUS_LG - INSET)
			draw_style_box(_box, Rect2(Vector2.ZERO, size))
		var preview := Design.ICON_MD + Design.SPACE_XS
		var origin := Vector2(Design.SPACE_MD, (size.y - preview) * 0.5)
		var cell_gap := maxf(1.0, preview * 0.06)
		var cell := (preview - cell_gap * (grid - 1)) / grid
		for gy in grid:
			for gx in grid:
				var value := 2 << ((gx + gy * 2) % 6)
				var pos := origin + Vector2(gx, gy) * (cell + cell_gap)
				draw_rect(Rect2(pos, Vector2(cell, cell)), p.tile_bg(value))
		var fs := Design.TEXT_BODY
		draw_string(_font, Vector2(origin.x + preview + Design.SPACE_MD, Fonts.baseline(size.y * 0.5, fs)), I18n.grid(grid),
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, p.accent if selected else p.text)
		if selected:
			Icons.draw(self, Icons.Kind.CHECK, Vector2(size.x - Design.SPACE_MD - Design.ICON_SM * 0.5, size.y * 0.5), Design.ICON_SM, p.accent)
