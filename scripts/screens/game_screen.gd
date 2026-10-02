class_name GameScreen
extends Control
## The play screen: scores, board, buttons, swipe and keyboard input, milestones, undo, hints
## and the game-over summary. Portrait: scores on top, buttons at the bottom under the thumb;
## landscape: the board in the middle, controls around it.

signal menu_requested

## Swipe length, in viewport pixels, that commits a move while the finger is still down.
const SWIPE_COMMIT := 44.0
## Shorter flicks still count when the finger lifts quickly.
const SWIPE_FLICK := 22.0
const FLICK_TIME_MS := 220
## Landscape: scores sit this close to the board's edges.
const BOARD_GAP := Design.SPACE_LG
## Landscape: minimum room between the menu button and the score beside it.
const BRAND_GAP := Design.SPACE_LG
const STACK_GAP := Design.SPACE_MD
const SCORE_SIZE := Vector2(Design.CONTROL_LG * 1.6, Design.CONTROL_LG)
## A landscape arrangement wins if its board is within this share of the largest one, so a
## slightly bigger board never beats the preferred layout.
const LAYOUT_TOLERANCE := 0.97
const CONFETTI := 70

## Seconds without a move before the hint button lights up on its own.
const HINT_IDLE := 15.0
## Thinking time for one hint; the search goes deeper on faster phones in the same time.
const HINT_BUDGET_MS := 350

## Landscape arrangements, preferred first. ROW: logo, menu and score in one line, best on the
## right. STACKED: score under logo and menu. ONE_SIDE: everything left of the board.
enum Arrangement { ROW, STACKED, ONE_SIDE }

var board := Board.new()

var _app: App
var _board_view := BoardView.new()
var _score_box := ScoreBox.make("SCORE")
var _best_box := ScoreBox.make("BEST")
var _undo_btn := PillButton.make("UNDO", PillButton.Look.SECONDARY, Icons.Kind.UNDO)
var _new_btn := PillButton.make("NEW", PillButton.Look.SECONDARY, Icons.Kind.RESTART)
var _menu_btn := PillButton.make_icon(Icons.Kind.MENU)
var _hint_btn := PillButton.make_icon(Icons.Kind.BULB)
var _logo := TileBadge.make(2048, Design.CONTROL_LG, "2048")
var _banner := MilestoneBanner.new()
var _confetti := CPUParticles2D.new()
var _game_over := GameOverOverlay.new()

var _header := HBoxContainer.new()
var _actions := HBoxContainer.new()
var _portrait := VBoxContainer.new()
var _landscape := Control.new()
var _brand := HBoxContainer.new()
var _side_actions := GridContainer.new()
var _landscape_mode := false
var _arrangement := Arrangement.ROW

var _touch_index := -1
var _touch_start := Vector2.ZERO
var _touch_time := 0
var _touch_used := false
var _pending_over := false
var _best_at_start := 0
var _record_flashed := false
## False until a game is started or resumed, so an empty board never overwrites a save.
var _active := false
## The current game already counts towards statistics (it ended in a loss).
var _recorded := false
var _solver := HintSolver.new()
## Background search in flight (WorkerThreadPool task id), or -1.
var _hint_task := -1
## Written by the search task; read once it has completed.
var _hint_result := -1
## Board the search started from; the answer is dropped if the board changed since.
var _hint_values := PackedInt64Array()
## Seconds since the last move while a game is waiting for one.
var _idle := 0.0
var _hint_glow_tween: Tween


func setup(app: App) -> void:
	_app = app


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_score_box.custom_minimum_size = SCORE_SIZE
	_best_box.custom_minimum_size = SCORE_SIZE
	for row in [_header, _actions, _brand]:
		row.add_theme_constant_override("separation", int(Design.SPACE_SM))
	_side_actions.add_theme_constant_override("h_separation", int(STACK_GAP))
	_side_actions.add_theme_constant_override("v_separation", int(STACK_GAP))
	_menu_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hint_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait.add_theme_constant_override("separation", int(Design.SPACE_LG))
	add_child(_portrait)
	_landscape.set_anchors_preset(Control.PRESET_FULL_RECT)
	_landscape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_landscape.visible = false
	add_child(_landscape)
	_landscape.resized.connect(_layout_landscape)
	# Undo can be hidden (depth 0) and labels or scores can change the space controls need.
	for node: Control in [_side_actions, _brand, _score_box, _best_box]:
		node.minimum_size_changed.connect(_layout_landscape)
	_apply_layout(false)

	_confetti.emitting = false
	_confetti.one_shot = true
	_confetti.amount = CONFETTI
	_confetti.lifetime = 1.6
	_confetti.explosiveness = 0.92
	_confetti.direction = Vector2.UP
	_confetti.spread = 55.0
	_confetti.initial_velocity_min = 560.0
	_confetti.initial_velocity_max = 1000.0
	_confetti.gravity = Vector2(0, 1500)
	_confetti.damping_min = 40.0
	_confetti.damping_max = 90.0
	_confetti.scale_amount_min = 7.0
	_confetti.scale_amount_max = 12.0
	_confetti.angle_min = -180.0
	_confetti.angle_max = 180.0
	_confetti.angular_velocity_min = -540.0
	_confetti.angular_velocity_max = 540.0
	_confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_confetti.emission_rect_extents = Vector2(200, 10)
	_confetti.z_index = 20
	add_child(_confetti)

	_banner.z_index = 10
	add_child(_banner)

	_menu_btn.pressed.connect(func() -> void: menu_requested.emit())
	_hint_btn.pressed.connect(request_hint)
	_undo_btn.pressed.connect(undo)
	_new_btn.pressed.connect(_ask_new_game)
	_board_view.settled.connect(_on_settled)
	_game_over.restart_requested.connect(_restart_from_over)
	_game_over.menu_requested.connect(_menu_from_over)


func _ready() -> void:
	# Hosted on the app overlay layer so the scrim also covers the safe-area margins.
	_app.add_overlay(_game_over)
	board.undo_limit = _app.store.undo_limit
	set_hints_enabled(_app.store.hints_on)
	_on_skin_changed()


func _exit_tree() -> void:
	if _hint_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_hint_task)
		_hint_task = -1


func _process(delta: float) -> void:
	if _hint_task >= 0 and WorkerThreadPool.is_task_completed(_hint_task):
		WorkerThreadPool.wait_for_task_completion(_hint_task)
		_hint_task = -1
		if _hint_result >= 0 and board.values == _hint_values and is_playing():
			# A player asking for a hint knows how to swipe; the tutorial would cover the suggestion.
			_board_view.hide_hint()
			_board_view.show_move_hint(_hint_result)
	var waiting := _app.store.hints_on and is_playing() and _app.is_current(self) \
			and not _app.is_modal_open() and not _board_view.is_animating() and _hint_task < 0 \
			and not _board_view.is_showing_move_hint()
	if waiting:
		_idle += delta
		if _idle >= HINT_IDLE and _hint_btn.glow == 0.0 and not _hint_glowing():
			_set_hint_glow(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var wide := size.x > size.y * 1.1
		if wide != _landscape_mode:
			_apply_layout(wide)
		_fit_actions()
		_banner.rest_y = SCORE_SIZE.y + Design.SPACE_LG
		_confetti.position = Vector2(size.x * 0.5, size.y * 0.55)
	elif what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree() and _pending_over:
		_on_settled()


func _on_skin_changed() -> void:
	var p := Palette.current
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	ramp.colors = PackedColorArray([p.tile_bg(8), p.tile_bg(256), p.tile_bg(2048), p.tile_bg(32)])
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	_confetti.color_initial_ramp = ramp


## Shows or hides the hint button; the layout closes the gap it leaves.
func set_hints_enabled(on: bool) -> void:
	_hint_btn.visible = on
	if not on:
		_set_hint_glow(false)
		_board_view.stop_move_hint()
	_fit_actions()
	_layout_landscape()


func _on_language_changed() -> void:
	# Buttons measure their new labels in their own handler, which runs after this one.
	_fit_actions.call_deferred()


## Portrait action bar: full buttons if they fit, then tighter ones, then labels without icons,
## then icons alone.
func _fit_actions() -> void:
	if _landscape_mode or size.x < 1.0:
		return
	for step in 4:
		for b: PillButton in [_undo_btn, _new_btn]:
			b.compact = step >= 1
			b.hide_icon = step == 2
			b.icon_only = step >= 3
		if _actions.get_combined_minimum_size().x <= size.x:
			return


## Works out the best move in the background, then shows it on the board without playing it.
func request_hint() -> void:
	_reset_idle()
	if not _app.store.hints_on or not is_playing() or _hint_task >= 0 or not board.can_move():
		return
	_board_view.stop_move_hint()
	_hint_values = board.values.duplicate()
	var values := _hint_values.duplicate()
	var grid := board.size
	_hint_result = -1
	_hint_task = WorkerThreadPool.add_task(func() -> void:
		_hint_result = _solver.best_move(values, grid, HINT_BUDGET_MS), false, "move hint")


func is_hint_busy() -> bool:
	return _hint_task >= 0


## A move happened: the idle clock restarts and a lit hint button goes back to normal.
func _reset_idle() -> void:
	_idle = 0.0
	_set_hint_glow(false)


func _hint_glowing() -> bool:
	return _hint_glow_tween != null and _hint_glow_tween.is_valid()


## Lights the hint button with a few slow pulses, then leaves it lit; or puts it out.
func _set_hint_glow(on: bool) -> void:
	if _hint_glow_tween:
		_hint_glow_tween.kill()
		_hint_glow_tween = null
	if not on:
		_hint_btn.glow = 0.0
		return
	_hint_glow_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hint_glow_tween.tween_property(_hint_btn, "glow", 1.0, 0.5)
	for pulse in 3:
		_hint_glow_tween.tween_property(_hint_btn, "glow", 0.45, 0.6)
		_hint_glow_tween.tween_property(_hint_btn, "glow", 1.0, 0.6)


func close_overlays() -> void:
	_game_over.close()


func is_modal_open() -> bool:
	return _game_over.is_open


## True while a game is on the board and not yet lost; the app counts play time only then.
func is_playing() -> bool:
	return _active and not _pending_over and not _game_over.is_open


## Starts a fresh game of side [param grid] (the current size when 0); tiles pop in with
## [param intro]. A replaced unfinished game counts as played.
func start_new(grid := 0, intro := true) -> void:
	_record_abandoned()
	board.new_game(grid if grid > 0 else board.size)
	_active = true
	_recorded = false
	_game_over.close()
	_pending_over = false
	_best_at_start = _app.store.best_for(board.size)
	_record_flashed = false
	_refresh_scores(false)
	_board_view.show_board(board, BoardView.Appear.POP if intro else BoardView.Appear.NONE)
	_board_view.show_hint()
	_reset_idle()
	_persist()


## Restores the saved game. Returns false when there is none or it is unreadable.
func resume_saved() -> bool:
	if not _app.store.has_game() or not board.from_dict(_app.store.game):
		return false
	_active = true
	_recorded = false
	_game_over.close()
	_pending_over = false
	_best_at_start = _app.store.best_for(board.size)
	_record_flashed = false
	_refresh_scores(false)
	_board_view.show_board(board, BoardView.Appear.POP)
	if board.move_count == 0:
		_board_view.show_hint()
	else:
		_board_view.hide_hint(true)
	if not board.can_move():
		_pending_over = true
	_reset_idle()
	return true


## Applies a new undo depth; lowering it drops the oldest steps of the current game.
func set_undo_limit(limit: int) -> void:
	board.undo_limit = limit
	_refresh_undo()
	if _active:
		_persist()


func request_move(dir: Board.Dir) -> void:
	if _game_over.is_open or _pending_over:
		return
	_reset_idle()
	var result := board.move(dir)
	if not result.moved:
		_board_view.nudge(dir)
		return
	_board_view.hide_hint()
	_board_view.play_move(result)
	_on_moved(result)


func undo() -> void:
	if _game_over.is_open:
		return
	var undone := board.undo()
	if undone == null:
		return
	_reset_idle()
	_app.store.record_move(board.size, -1)
	_pending_over = false
	if undone.moved:
		_board_view.play_undo(undone)
	else:
		_board_view.show_board(board, BoardView.Appear.FADE)
	_refresh_scores(true)
	_app.sfx.play(Sfx.Kind.SWIPE, 0.8, -4.0)
	_persist()


## Persists the game in progress; a finished game is not resumable.
func save_state() -> void:
	if _active:
		_app.store.game = board.to_dict() if board.can_move() else {}


## True while the milestone banner or confetti is on screen.
func is_celebrating() -> bool:
	return _confetti.emitting or _banner.visible


func _on_moved(result: Board.MoveResult) -> void:
	if result.merges.is_empty():
		_app.sfx.play(Sfx.Kind.SWIPE, randf_range(0.95, 1.08), -6.0)
	else:
		var top := 0
		for m in result.merges:
			top = maxi(top, m[3])
		_app.sfx.play_merge(top)
		_app.haptic_merge(top / 2)
	if result.gained > 0:
		_score_box.pop_gain(result.gained)
	_app.store.record_move(board.size)
	_app.store.record_best_tile(board.size, board.best_tile)
	if _app.store.submit_score(board.score, board.size) and _best_at_start > 0 and not _record_flashed:
		_record_flashed = true
		_best_box.flash()
	_refresh_scores(true)
	if not result.milestones.is_empty():
		_celebrate(result.milestones[result.milestones.size() - 1])
	if not board.can_move():
		_pending_over = true
	_persist()


func _celebrate(value: int) -> void:
	_banner.celebrate(value)
	_app.sfx.play(Sfx.Kind.MILESTONE, 1.0, -1.0)
	_confetti.amount = CONFETTI if value < 2048 else CONFETTI * 2
	_confetti.restart()


func _on_settled() -> void:
	if not _pending_over or _game_over.is_open:
		return
	await get_tree().create_timer(0.35).timeout
	# Not over the menu or settings if the player left meanwhile; it shows on return instead.
	if not _pending_over or _game_over.is_open or not _app.is_current(self):
		return
	_app.sfx.play(Sfx.Kind.LOSE)
	_app.haptic_game_over()
	if not _recorded:
		_recorded = true
		_app.store.record_game(board.size, board.score, board.best_tile)
		_app.save_now()
	var record := board.score > _best_at_start and board.score > 0
	_game_over.present(board.score, board.best_tile, board.move_count, record)


func prime_overlays() -> void:
	_game_over.prime()


## Counts the game being replaced if it had any moves and was not already counted.
func _record_abandoned() -> void:
	if _active:
		if board.move_count > 0 and not _recorded:
			_app.store.record_game(board.size, board.score, board.best_tile)
		return
	# Not loaded yet (fresh launch): the saved game from disk is the one being replaced.
	if _app.store.has_game():
		var saved := Board.new(1)
		if saved.from_dict(_app.store.game) and saved.move_count > 0:
			_app.store.record_game(saved.size, saved.score, saved.best_tile)


func _refresh_scores(animate: bool) -> void:
	_score_box.set_value(board.score, animate)
	_best_box.set_value(_app.store.best_for(board.size), animate)
	_refresh_undo()


func _refresh_undo() -> void:
	_undo_btn.visible = board.undo_limit > 0
	_undo_btn.disabled = not board.can_undo()
	_undo_btn.badge = board.undo_available() if board.undo_limit > 1 else 0


func _persist() -> void:
	save_state()
	_app.request_save()


func _ask_new_game() -> void:
	if board.move_count == 0 or not board.can_move():
		start_new()
		return
	_app.confirm("CONFIRM_NEW_TITLE", "CONFIRM_NEW_BODY", "YES_NEW", start_new)


func _restart_from_over() -> void:
	_game_over.close()
	start_new()


func _menu_from_over() -> void:
	_game_over.close()
	menu_requested.emit()


## Portrait: header above the board, action bar below. Landscape: board in the middle, controls
## placed by [method _layout_landscape].
func _apply_layout(wide: bool) -> void:
	_landscape_mode = wide
	# Narrower buttons leave the board more room beside them.
	for b: PillButton in [_undo_btn, _new_btn]:
		b.compact = wide
		b.hide_icon = false
		b.icon_only = false
	if _board_view.get_parent():
		_board_view.get_parent().remove_child(_board_view)
	if wide:
		_fill(_brand, [_logo, _menu_btn])
		_fill(_side_actions, [_undo_btn, _new_btn])
		for node: Control in [_board_view, _brand, _score_box, _best_box, _side_actions, _hint_btn]:
			if node.get_parent():
				node.get_parent().remove_child(node)
			_landscape.add_child(node)
	else:
		for node: Control in [_brand, _side_actions]:
			if node.get_parent():
				node.get_parent().remove_child(node)
		_fill(_header, [_logo, null, _score_box, _best_box])
		_fill(_actions, [_menu_btn, _hint_btn, null, _undo_btn, _new_btn])
		_fill(_portrait, [_header, _board_view, _actions])
	_portrait.visible = not wide
	_landscape.visible = wide
	_layout_landscape()


## Makes [param nodes] the children of [param box] in order; null entries become spacers.
func _fill(box: Container, nodes: Array) -> void:
	for child in box.get_children():
		box.remove_child(child)
		if not child in [_logo, _score_box, _best_box, _menu_btn, _hint_btn, _undo_btn, _new_btn,
				_board_view, _header, _actions, _brand, _side_actions]:
			child.queue_free()
	for node in nodes:
		if node == null:
			box.add_child(_hspacer())
			continue
		if node.get_parent():
			node.get_parent().remove_child(node)
		box.add_child(node)


## Sizes the board and places the controls around it: logo and menu top-left, score against the
## board's left edge, best score and hint against its right edge, undo and new game bottom-left.
## Falls back to stacked arrangements when that would shrink the board.
func _layout_landscape() -> void:
	if not _landscape_mode:
		return
	var area := _landscape.size
	if area.x < 1.0 or area.y < 1.0:
		return
	var sides := {}
	var best_side := 0.0
	for arrangement: Arrangement in Arrangement.values():
		sides[arrangement] = _board_side(arrangement, area)
		best_side = maxf(best_side, sides[arrangement])
	_arrangement = Arrangement.ONE_SIDE
	for arrangement: Arrangement in Arrangement.values():
		if sides[arrangement] >= best_side * LAYOUT_TOLERANCE:
			_arrangement = arrangement
			break
	var s := maxf(sides[_arrangement], 0.0)
	var x := (area.x - s) * 0.5
	if _arrangement == Arrangement.ONE_SIDE:
		var left := _left_width(_arrangement)
		x = left + BOARD_GAP + (area.x - left - BOARD_GAP - s) * 0.5
	var y := (area.y - s) * 0.5
	_side_actions.columns = _action_columns(_arrangement)
	var brand := _brand.get_combined_minimum_size()
	var score := _score_box.get_combined_minimum_size()
	var best := _best_box.get_combined_minimum_size()
	var actions := _side_actions.get_combined_minimum_size()
	var hint := _hint_btn.get_combined_minimum_size()
	_place(_board_view, Vector2(x, y), Vector2(s, s))
	_place(_brand, Vector2(0.0, y), brand)
	_place(_side_actions, Vector2(0.0, y + s - actions.y), actions)
	match _arrangement:
		Arrangement.ROW:
			_place(_score_box, Vector2(x - BOARD_GAP - score.x, y), score)
			_place(_best_box, Vector2(x + s + BOARD_GAP, y), best)
		Arrangement.STACKED:
			_place(_score_box, Vector2(x - BOARD_GAP - score.x, y + brand.y + STACK_GAP), score)
			_place(_best_box, Vector2(x + s + BOARD_GAP, y), best)
		Arrangement.ONE_SIDE:
			_place(_score_box, Vector2(0.0, y + brand.y + STACK_GAP), score)
			_place(_best_box, Vector2(0.0, y + brand.y + score.y + STACK_GAP * 2.0), best)
	_place(_hint_btn, _best_box.position + Vector2(best.x + STACK_GAP, (best.y - hint.y) * 0.5), hint)


## Board side [param arrangement] allows in [param area], or -1 when its controls do not fit.
func _board_side(arrangement: Arrangement, area: Vector2) -> float:
	var left := _left_width(arrangement)
	var s := area.y
	if arrangement == Arrangement.ONE_SIDE:
		s = minf(s, area.x - left - BOARD_GAP)
	else:
		var right := _best_box.get_combined_minimum_size().x + _hint_width()
		s = minf(s, area.x - 2.0 * (maxf(left, right) + BOARD_GAP))
	return s if s >= _left_height(arrangement) else -1.0


func _left_width(arrangement: Arrangement) -> float:
	var brand := _brand.get_combined_minimum_size().x
	var score := _score_box.get_combined_minimum_size().x
	var width := maxf(brand, score)
	match arrangement:
		Arrangement.ROW:
			width = brand + BRAND_GAP + score
		Arrangement.ONE_SIDE:
			width = maxf(width, _best_box.get_combined_minimum_size().x + _hint_width())
	return maxf(width, _actions_size(_action_columns(arrangement)).x)


## Room the hint button takes beside the best score, with its gap; none when hints are off.
func _hint_width() -> float:
	return STACK_GAP + _hint_btn.get_combined_minimum_size().x if _hint_btn.visible else 0.0


## Height the left-hand controls need: the top group plus the buttons at the bottom.
func _left_height(arrangement: Arrangement) -> float:
	var brand := _brand.get_combined_minimum_size().y
	var score := _score_box.get_combined_minimum_size().y
	var top := maxf(brand, score)
	match arrangement:
		Arrangement.STACKED:
			top = brand + STACK_GAP + score
		Arrangement.ONE_SIDE:
			top = brand + score + _best_box.get_combined_minimum_size().y + STACK_GAP * 2.0
	return top + STACK_GAP + _actions_size(_action_columns(arrangement)).y


## Undo and new game side by side, unless that is wider than the controls above them.
func _action_columns(arrangement: Arrangement) -> int:
	var brand := _brand.get_combined_minimum_size().x
	var score := _score_box.get_combined_minimum_size().x
	var column := brand + BRAND_GAP + score if arrangement == Arrangement.ROW else maxf(brand, score)
	return 2 if _actions_size(2).x <= column else 1


func _actions_size(columns: int) -> Vector2:
	var out := Vector2.ZERO
	var first := true
	for button: Control in [_undo_btn, _new_btn]:
		if not button.visible:
			continue
		var m := button.get_combined_minimum_size()
		if first:
			out = m
		elif columns == 1:
			out = Vector2(maxf(out.x, m.x), out.y + STACK_GAP + m.y)
		else:
			out = Vector2(out.x + STACK_GAP + m.x, maxf(out.y, m.y))
		first = false
	return out


func _place(node: Control, pos: Vector2, node_size: Vector2) -> void:
	node.position = pos.round()
	node.size = node_size.round()


func _hspacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _accepts_input() -> bool:
	return _app.is_current(self) and not _game_over.is_open and not _app.is_modal_open()


func _input(event: InputEvent) -> void:
	if not _accepts_input():
		_touch_index = -1
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index < 0:
			if not _in_swipe_area(event.position):
				return
			_touch_index = event.index
			_touch_start = event.position
			_touch_time = Time.get_ticks_msec()
			_touch_used = false
		elif not event.pressed and event.index == _touch_index:
			var quick := Time.get_ticks_msec() - _touch_time <= FLICK_TIME_MS
			if not _touch_used and quick:
				_try_swipe(event.position - _touch_start, SWIPE_FLICK)
			_touch_index = -1
	elif event is InputEventScreenDrag and event.index == _touch_index and not _touch_used:
		_try_swipe(event.position - _touch_start, SWIPE_COMMIT)


## Swipes may start anywhere except on the scores and buttons or past the screen's edge, so
## checking the time or pulling the notification shade never moves tiles.
func _in_swipe_area(point: Vector2) -> bool:
	if not get_global_rect().has_point(point):
		return false
	if not _landscape_mode:
		return point.y > _header.get_global_rect().end.y + Design.SPACE_XS \
				and point.y < _actions.get_global_rect().position.y - Design.SPACE_XS
	if _side_actions.get_global_rect().grow(Design.SPACE_SM).has_point(point):
		return false
	var board := _board_view.get_global_rect()
	if point.x >= board.position.x - Design.SPACE_XS and point.x <= board.end.x + Design.SPACE_XS:
		return true
	var top_end := 0.0
	for node: Control in [_brand, _score_box, _best_box, _hint_btn]:
		if node.visible:
			top_end = maxf(top_end, node.get_global_rect().end.y)
	return point.y > top_end + Design.SPACE_SM


func _unhandled_input(event: InputEvent) -> void:
	if not _accepts_input():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var dir: int = -1
	match event.physical_keycode:
		KEY_LEFT, KEY_A: dir = Board.Dir.LEFT
		KEY_RIGHT, KEY_D: dir = Board.Dir.RIGHT
		KEY_UP, KEY_W: dir = Board.Dir.UP
		KEY_DOWN, KEY_S: dir = Board.Dir.DOWN
		KEY_Z, KEY_BACKSPACE:
			undo()
			get_viewport().set_input_as_handled()
			return
		KEY_H:
			request_hint()
			get_viewport().set_input_as_handled()
			return
	if dir >= 0:
		request_move(dir)
		get_viewport().set_input_as_handled()


func _try_swipe(delta: Vector2, threshold: float) -> void:
	# Positions arrive in viewport units, so the thresholds do not depend on screen density.
	if delta.length() < threshold:
		return
	_touch_used = true
	if absf(delta.x) > absf(delta.y):
		request_move(Board.Dir.RIGHT if delta.x > 0 else Board.Dir.LEFT)
	else:
		request_move(Board.Dir.DOWN if delta.y > 0 else Board.Dir.UP)
