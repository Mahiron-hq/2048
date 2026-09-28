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


## Opens next to [param anchor] (global rect) with [param current] marked.
func open_at(anchor: Rect2, current: int) -> void:
	for child in _list.get_children():
		child.queue_free()
	for n in range(Board.MIN_SIZE, Board.MAX_SIZE + 1):
		var row := _Row.new()
		row.grid = n
		row.selected = n == current
		row.custom_minimum_size = Vector2(maxf(anchor.size.x, MIN_WIDTH) - 20.0, ROW_HEIGHT)
		row.pressed.connect(_choose.bind(n))
		_list.add_child(row)
	is_open = true
	show()
	_card.modulate.a = 0.0
	_card.reset_size()
	await get_tree().process_frame
	if not is_open:
		return
	var local := get_global_transform().affine_inverse() * anchor.position
	var card_size := _card.get_combined_minimum_size()
	_card.size = card_size
	var above := local.y - card_size.y - 12.0
	var y := above if above >= 8.0 else local.y + anchor.size.y + 12.0
	var x := clampf(local.x, 8.0, maxf(8.0, size.x - card_size.x - 8.0))
	_card.position = Vector2(x, y)
	_card.pivot_offset = Vector2(card_size.x * 0.2, card_size.y if above >= 8.0 else 0.0)
	_card.scale = Vector2(0.92, 0.92)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_card, "modulate:a", 1.0, 0.14)
	_tween.tween_property(_card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
