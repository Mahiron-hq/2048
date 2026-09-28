class_name BoardView
extends Control
## Draws the grid and animates tiles for moves reported by [Board].
##
## Tile nodes are pooled; a move only repositions, recolors and rescales existing nodes.
## A new move arriving mid-animation fast-forwards the running one, so input is never dropped.

signal settled

enum Appear { NONE, POP, FADE }

const SLIDE_TIME := 0.105
const MERGE_TIME := 0.17
const SPAWN_TIME := 0.2
const RING_MIN_VALUE := 64
const UNDO_VANISH := 0.12
const UNDO_SQUEEZE := 0.07
const UNDO_SQUEEZE_SCALE := 0.9
const UNDO_SLIDE := 0.19

var cell_size := 100.0
var gap := 12.0
var board_rect := Rect2()
## Side length of the grid currently shown.
var grid_size := Board.DEFAULT_SIZE
## Horizontal shift of the board from the middle of this control (clamped to stay inside it);
## lets the parent center the board on the screen rather than in this control.
var center_offset_x := 0.0:
	set(v):
		if not is_equal_approx(v, center_offset_x):
			center_offset_x = v
			_layout()

var _layer := Control.new()
var _fx_layer := Control.new()
var _hint := SwipeHint.new()
var _tiles := {}
var _pool: Array[TileView] = []
var _rings: Array[MergeRing] = []
var _move_tween: Tween
var _fx_tweens: Array[Tween] = []
var _nudge_tween: Tween
var _styles := {}
var _font_sizes := {}
var _font: Font = Fonts.sans(Fonts.BLACK)
var _board_box := StyleBoxFlat.new()
var _cell_box := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for layer in [_layer, _fx_layer]:
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(layer)
	_hint.z_index = 4
	add_child(_hint)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func is_animating() -> bool:
	return (_move_tween != null and _move_tween.is_valid()) or _fx_tweens.any(func(t: Tween) -> bool: return t.is_valid())


## Rebuilds tiles from [param board] without replaying a move.
func show_board(board: Board, appear := Appear.NONE) -> void:
	complete_animations()
	for id in _tiles.keys():
		_release(_tiles[id])
	_tiles.clear()
	if board.size != grid_size:
		grid_size = board.size
		_layout()
	var order := 0
	for i in board.cell_count:
		if board.values[i] == 0:
			continue
		var t := _acquire(board.ids[i], board.values[i], i)
		match appear:
			Appear.POP:
				t.scale = Vector2.ZERO
				var tw := _fx_tween()
				tw.tween_interval(0.035 * order)
				tw.tween_property(t, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				order += 1
			Appear.FADE:
				t.modulate.a = 0.0
				t.scale = Vector2(0.92, 0.92)
				var tw := _fx_tween().set_parallel()
				tw.tween_property(t, "modulate:a", 1.0, 0.16)
				tw.tween_property(t, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_watch_settle()


## Animates one successful move: slide, then merge pops and the spawned tile.
func play_move(result: Board.MoveResult) -> void:
	complete_animations()
	_move_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for s in result.slides:
		var t: TileView = _tiles.get(s[0])
		if t:
			_move_tween.tween_property(t, "position", cell_position(s[2]), SLIDE_TIME)
	_move_tween.chain().tween_callback(_after_slide.bind(result))


## Plays [param undone] backwards: the spawned tile shrinks away, merged tiles squeeze and split
## into their halves, and every tile glides back to where it came from.
func play_undo(undone: Board.MoveResult) -> void:
	complete_animations()
	var tw := create_tween().set_parallel()
	_move_tween = tw
	if not undone.spawn.is_empty():
		var spawned: TileView = _tiles.get(undone.spawn[0])
		if spawned:
			_tiles.erase(undone.spawn[0])
			spawned.z_index = 3
			tw.tween_property(spawned, "scale", Vector2.ZERO, UNDO_VANISH).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.tween_property(spawned, "modulate:a", 0.0, UNDO_VANISH)
			tw.tween_callback(_release.bind(spawned)).set_delay(UNDO_VANISH)
	for m in undone.merges:
		var survivor: TileView = _tiles.get(m[0])
		if survivor == null:
			continue
		# The consumed half waits underneath, slightly smaller, until the pair splits.
		var half := _acquire(m[1], m[3] / 2, m[2])
		half.scale = Vector2(UNDO_SQUEEZE_SCALE, UNDO_SQUEEZE_SCALE) * 0.95
		half.z_index = 1
		survivor.z_index = 2
		var squeezed := Vector2(UNDO_SQUEEZE_SCALE, UNDO_SQUEEZE_SCALE)
		tw.tween_property(survivor, "scale", squeezed, UNDO_SQUEEZE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(survivor.set_value.bind(m[3] / 2)).set_delay(UNDO_SQUEEZE)
		for t in [survivor, half]:
			tw.tween_property(t, "scale", Vector2.ONE, UNDO_SLIDE).set_delay(UNDO_SQUEEZE) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for s in undone.slides:
		var t: TileView = _tiles.get(s[0])
		if t:
			t.set_meta("cell", s[1])
			tw.tween_property(t, "position", cell_position(s[1]), UNDO_SLIDE).set_delay(UNDO_SQUEEZE) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_after_undo).set_delay(UNDO_SQUEEZE + UNDO_SLIDE)


## Shows the swipe hint over the board (start of a game).
func show_hint() -> void:
	_hint.appear()


## Fades the swipe hint out; used on the first move.
func hide_hint(instant := false) -> void:
	_hint.dismiss(instant)


func is_hint_visible() -> bool:
	return _hint.is_showing()


## Small bump towards [param dir] for a swipe that changes nothing.
func nudge(dir: Board.Dir) -> void:
	if _nudge_tween and _nudge_tween.is_valid():
		return
	var off := Vector2.ZERO
	match dir:
		Board.Dir.LEFT: off = Vector2.LEFT
		Board.Dir.RIGHT: off = Vector2.RIGHT
		Board.Dir.UP: off = Vector2.UP
		Board.Dir.DOWN: off = Vector2.DOWN
	_nudge_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_nudge_tween.tween_property(_layer, "position", off * cell_size * 0.06, 0.06).set_ease(Tween.EASE_OUT)
	_nudge_tween.tween_property(_layer, "position", Vector2.ZERO, 0.14).set_ease(Tween.EASE_IN_OUT)


## Jumps every running animation to its end state.
func complete_animations() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.custom_step(10.0)
	_move_tween = null
	var running := _fx_tweens
	_fx_tweens = []
	for tw in running:
		if tw.is_valid():
			tw.custom_step(10.0)


func cell_position(index: int) -> Vector2:
	var x := index % grid_size
	var y := index / grid_size
	return board_rect.position + Vector2(gap + x * (cell_size + gap), gap + y * (cell_size + gap))


func tile_depth() -> float:
	return roundf(cell_size * 0.045)


func tile_font() -> Font:
	return _font


## [base, face] style boxes for a tile of [param value].
func tile_styles(value: int) -> Array:
	if _styles.has(value):
		return _styles[value]
	var p := Palette.current
	var bg := p.tile_bg(value)
	var radius := int(cell_size * 0.15)
	var base := StyleBoxFlat.new()
	base.bg_color = bg.darkened(0.16 if not p.dark else 0.3)
	base.set_corner_radius_all(radius)
	base.corner_detail = 10
	if p.tile_glows(value):
		base.shadow_color = Color(bg, 0.55 if p.dark else 0.45)
		base.shadow_size = int(cell_size * 0.16)
	else:
		base.shadow_color = p.shadow
		base.shadow_size = int(cell_size * 0.05)
		base.shadow_offset = Vector2(0, cell_size * 0.02)
	var face := StyleBoxFlat.new()
	face.bg_color = bg
	face.set_corner_radius_all(radius)
	face.corner_detail = 10
	face.border_color = bg.lightened(0.18)
	face.border_width_top = maxi(1, int(cell_size * 0.012))
	face.border_blend = true
	_styles[value] = [base, face]
	return _styles[value]


func tile_font_size(value: int) -> int:
	if _font_sizes.has(value):
		return _font_sizes[value]
	var txt := str(value)
	var ratios := [0.5, 0.5, 0.44, 0.36, 0.3, 0.25, 0.21]
	var fs := int(cell_size * ratios[mini(txt.length(), ratios.size() - 1)])
	var limit := cell_size * 0.82
	while fs > 8 and _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > limit:
		fs -= 1
	_font_sizes[value] = fs
	return fs


func _on_skin_changed() -> void:
	_styles.clear()
	_update_boxes()
	queue_redraw()
	for t in _tiles.values():
		t.queue_redraw()


func _draw() -> void:
	draw_style_box(_board_box, board_rect)
	for i in grid_size * grid_size:
		draw_style_box(_cell_box, Rect2(cell_position(i), Vector2(cell_size, cell_size)))


func _layout() -> void:
	var s := minf(size.x, size.y)
	if s < 40.0:
		return
	# Sit above center: the thumb zone below the board stays free and the layout feels less floaty.
	var free := size - Vector2(s, s)
	var x := clampf(free.x * 0.5 + center_offset_x, 0.0, free.x)
	board_rect = Rect2(Vector2(x, free.y * 0.28), Vector2(s, s))
	# Gaps shrink a little on bigger grids so cells keep a usable size.
	gap = roundf(s * 0.15 / (grid_size + 1))
	cell_size = (s - gap * (grid_size + 1)) / grid_size
	_hint.board_radius = cell_size * 0.22
	_hint.board_rect = board_rect
	_styles.clear()
	_font_sizes.clear()
	_update_boxes()
	complete_animations()
	for i in _layer.get_child_count():
		var t := _layer.get_child(i) as TileView
		if t and t.visible:
			t.size = Vector2(cell_size, cell_size)
			t.pivot_offset = t.size * 0.5
	for id in _tiles:
		var t: TileView = _tiles[id]
		t.position = cell_position(t.get_meta("cell", 0))
	queue_redraw()


func _update_boxes() -> void:
	var p := Palette.current
	_board_box.bg_color = p.board
	_board_box.set_corner_radius_all(int(cell_size * 0.22))
	_board_box.corner_detail = 12
	_board_box.shadow_color = p.shadow
	_board_box.shadow_size = int(cell_size * 0.18)
	_board_box.shadow_offset = Vector2(0, cell_size * 0.06)
	_cell_box.bg_color = p.cell
	_cell_box.set_corner_radius_all(int(cell_size * 0.15))
	_cell_box.corner_detail = 10


func _after_slide(result: Board.MoveResult) -> void:
	for m in result.merges:
		var consumed: TileView = _tiles.get(m[1])
		if consumed:
			_tiles.erase(m[1])
			_release(consumed)
		var survivor: TileView = _tiles.get(m[0])
		if survivor == null:
			continue
		survivor.set_meta("cell", m[2])
		survivor.set_value(m[3])
		survivor.z_index = 2
		var tw := _fx_tween()
		tw.tween_property(survivor, "scale", Vector2(1.2, 1.2), MERGE_TIME * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(survivor, "scale", Vector2.ONE, MERGE_TIME * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(survivor.set.bind("z_index", 0))
		if m[3] >= RING_MIN_VALUE:
			_ring_at(m[2], Palette.current.tile_bg(m[3]))
	for s in result.slides:
		var t: TileView = _tiles.get(s[0])
		if t:
			t.set_meta("cell", s[2])
	if not result.spawn.is_empty():
		var t := _acquire(result.spawn[0], result.spawn[2], result.spawn[1])
		t.scale = Vector2.ZERO
		var tw := _fx_tween()
		tw.tween_interval(0.03)
		tw.tween_property(t, "scale", Vector2.ONE, SPAWN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_watch_settle()


func _ring_at(index: int, color: Color) -> void:
	var ring: MergeRing = null
	for r in _rings:
		if not r.visible:
			ring = r
			break
	if ring == null:
		ring = MergeRing.new()
		_fx_layer.add_child(ring)
		_rings.append(ring)
	var c := cell_position(index) + Vector2(cell_size, cell_size) * 0.5
	ring.play(c, cell_size, color)
	var tw := _fx_tween()
	tw.tween_property(ring, "t", 1.0, 0.45).from(0.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(ring.hide)


func _after_undo() -> void:
	for t in _tiles.values():
		t.z_index = 0
	settled.emit()


func _watch_settle() -> void:
	var tw := _fx_tween()
	tw.tween_interval(maxf(SPAWN_TIME, MERGE_TIME) + 0.05)
	tw.tween_callback(settled.emit)


func _fx_tween() -> Tween:
	var i := _fx_tweens.size() - 1
	while i >= 0:
		if not _fx_tweens[i].is_valid():
			_fx_tweens.remove_at(i)
		i -= 1
	var tw := create_tween()
	_fx_tweens.append(tw)
	return tw


func _acquire(id: int, value: int, index: int) -> TileView:
	var t: TileView
	if _pool.is_empty():
		t = TileView.new()
		t.view = self
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(t)
	else:
		t = _pool.pop_back()
	t.size = Vector2(cell_size, cell_size)
	t.pivot_offset = t.size * 0.5
	t.position = cell_position(index)
	t.scale = Vector2.ONE
	t.modulate = Color.WHITE
	t.z_index = 0
	t.set_meta("cell", index)
	t.set_value(value)
	t.show()
	_tiles[id] = t
	return t


func _release(t: TileView) -> void:
	t.hide()
	t.value = 0
	_pool.append(t)


## Expanding halo shown when a high tile is formed.
class MergeRing:
	extends Control

	var t := 0.0:
		set(v):
			t = v
			queue_redraw()
	var _radius := 50.0
	var _color := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func play(center: Vector2, cell: float, color: Color) -> void:
		position = center
		_radius = cell * 0.5
		_color = color
		t = 0.0
		show()

	func _draw() -> void:
		var r := _radius * (1.0 + 0.6 * t)
		var a := (1.0 - t) * 0.8
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(_color, a), _radius * 0.16 * (1.0 - t) + 1.0, true)
