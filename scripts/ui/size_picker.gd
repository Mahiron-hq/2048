class_name SizePicker
extends Control
## Small popover listing the board sizes, anchored to the button that opened it.
## A tap outside the card closes it.

signal chosen(size: int)

const ROW_HEIGHT := 84.0
const MIN_WIDTH := 300.0

var is_open := false

var _card := Card.make(10, 30)
var _list := VBoxContainer.new()
var _tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_list.add_theme_constant_override("separation", 4)
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
		row.custom_minimum_size = Vector2(width - 20.0, ROW_HEIGHT)
		row.queue_redraw()
	is_open = true
	show()
	_card.modulate.a = 0.0
	_card.size = Vector2.ZERO
	var card_size := _card.get_combined_minimum_size()
	_card.size = card_size
	var local := get_global_transform().affine_inverse() * anchor.position
	var area := get_rect().size
	var space_above := local.y - 12.0
	var space_below := area.y - (local.y + anchor.size.y + 12.0)
	var above := space_above >= card_size.y or space_above >= space_below
	var y := local.y - card_size.y - 12.0 if above else local.y + anchor.size.y + 12.0
	y = clampf(y, 8.0, maxf(8.0, area.y - card_size.y - 8.0))
	var x := clampf(local.x, 8.0, maxf(8.0, area.x - card_size.x - 8.0))
	_card.position = Vector2(x, y)
	# Short landscape screens: shrink the card rather than let it leave the screen.
	var fit := minf(1.0, (area.y - 16.0) / card_size.y)
	_card.pivot_offset = Vector2(card_size.x * 0.2, card_size.y if above else 0.0)
	if fit < 1.0:
		_card.position.y = 8.0
		_card.pivot_offset = Vector2(card_size.x * 0.2, 0.0)
	_card.scale = Vector2(0.92, 0.92) * fit
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_card, "modulate:a", 1.0, 0.14)
	_tween.tween_property(_card, "scale", Vector2(fit, fit), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not is_open:
		return
	is_open = false
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_card, "modulate:a", 0.0, 0.12)
	_tween.tween_property(_card, "scale", Vector2(0.95, 0.95), 0.12)
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
	var _font: Font = Fonts.sans(Fonts.BOLD)
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
			_box.bg_color = Color(p.accent, 0.16 if selected else 0.08)
			_box.set_corner_radius_all(20)
			_box.corner_detail = 8
			draw_style_box(_box, Rect2(Vector2.ZERO, size))
		var preview := size.y * 0.56
		var origin := Vector2(18.0, (size.y - preview) * 0.5)
		var cell_gap := preview * 0.06
		var cell := (preview - cell_gap * (grid - 1)) / grid
		for gy in grid:
			for gx in grid:
				var value := 2 << ((gx + gy * 2) % 6)
				var pos := origin + Vector2(gx, gy) * (cell + cell_gap)
				draw_rect(Rect2(pos, Vector2(cell, cell)), p.tile_bg(value))
		var label := I18n.grid(grid)
		var fs := 30
		draw_string(_font, Vector2(origin.x + preview + 22.0, size.y * 0.5 + fs * 0.36), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, p.accent if selected else p.text)
		if selected:
			Icons.draw(self, Icons.Kind.CHECK, Vector2(size.x - 34.0, size.y * 0.5), 30.0, p.accent)
