class_name GameScreen
extends Control
## The play screen: header with scores, action row, board, swipe/keyboard input, milestones,
## undo, the start-of-game swipe hint and the game-over summary. Portrait stacks header,
## actions and board; landscape puts header and actions in a side panel next to the board.

signal menu_requested

## Swipe length, in viewport pixels, that commits a move while the finger is still down.
const SWIPE_COMMIT := 44.0
## Shorter flicks still count when the finger lifts quickly.
const SWIPE_FLICK := 22.0
const FLICK_TIME_MS := 220
const SIDE_PANEL_WIDTH := 540.0

var board := Board.new()

var _app: App
var _board_view := BoardView.new()
var _score_box := ScoreBox.make("SCORE")
var _best_box := ScoreBox.make("BEST")
var _undo_btn := PillButton.make("UNDO", PillButton.Look.SECONDARY, Icons.Kind.UNDO, 76)
var _new_btn := PillButton.make("NEW", PillButton.Look.SECONDARY, Icons.Kind.RESTART, 76)
var _menu_btn := PillButton.make_icon(Icons.Kind.MENU, 76)
var _logo := TileBadge.make(2048, 112, "2048")
var _banner := MilestoneBanner.new()
var _confetti := CPUParticles2D.new()
var _game_over := GameOverOverlay.new()

var _header := HBoxContainer.new()
var _actions := HBoxContainer.new()
var _portrait := VBoxContainer.new()
var _landscape := HBoxContainer.new()
var _side := VBoxContainer.new()
var _landscape_mode := false

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


func setup(app: App) -> void:
	_app = app


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_header.add_theme_constant_override("separation", 14)
	_logo.text_ratio = 0.3
	_header.add_child(_logo)
	_header.add_child(_hspacer())
	_score_box.custom_minimum_size = Vector2(172, 112)
	_best_box.custom_minimum_size = Vector2(172, 112)
	_header.add_child(_score_box)
	_header.add_child(_best_box)

	_actions.add_theme_constant_override("separation", 14)
	_actions.add_child(_menu_btn)
	_actions.add_child(_hspacer())
	_actions.add_child(_undo_btn)
	_actions.add_child(_new_btn)

	_board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait.add_theme_constant_override("separation", 26)
	add_child(_portrait)
	_landscape.set_anchors_preset(Control.PRESET_FULL_RECT)
	_landscape.add_theme_constant_override("separation", 48)
	_landscape.visible = false
	add_child(_landscape)
	_side.alignment = BoxContainer.ALIGNMENT_CENTER
	_side.add_theme_constant_override("separation", 26)
	_side.custom_minimum_size.x = SIDE_PANEL_WIDTH
	_apply_layout(false)

	_confetti.emitting = false
	_confetti.one_shot = true
	_confetti.amount = 90
	_confetti.lifetime = 1.8
	_confetti.explosiveness = 0.92
	_confetti.direction = Vector2.UP
	_confetti.spread = 65.0
	_confetti.initial_velocity_min = 620.0
	_confetti.initial_velocity_max = 1150.0
	_confetti.gravity = Vector2(0, 1500)
	_confetti.damping_min = 40.0
	_confetti.damping_max = 90.0
	_confetti.scale_amount_min = 9.0
	_confetti.scale_amount_max = 16.0
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
	_undo_btn.pressed.connect(undo)
	_new_btn.pressed.connect(_ask_new_game)
	_board_view.settled.connect(_on_settled)
	_game_over.restart_requested.connect(_restart_from_over)
	_game_over.menu_requested.connect(_menu_from_over)


func _ready() -> void:
	# Hosted on the app overlay layer so the scrim also covers the safe-area margins.
	_app.add_overlay(_game_over)
	board.undo_limit = _app.store.undo_limit
	_on_skin_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var wide := size.x > size.y * 1.1
		if wide != _landscape_mode:
			_apply_layout(wide)
		_banner.rest_y = 128.0
		_confetti.position = Vector2(size.x * 0.5, size.y * 0.55)


func _on_skin_changed() -> void:
	var p := Palette.current
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	ramp.colors = PackedColorArray([p.tile_bg(16), p.tile_bg(128), p.accent, p.tile_bg(4096), p.tile_bg(64)])
	_confetti.color_initial_ramp = ramp


func close_overlays() -> void:
	_game_over.close()


func is_modal_open() -> bool:
	return _game_over.is_open


## True while a game is on the board and not yet lost; the app counts play time only then.
func is_playing() -> bool:
	return _active and not _pending_over and not _game_over.is_open


## Starts a fresh game of side [param grid] (the current size when 0). With [param intro],
## tiles pop in. An unfinished game that is replaced counts as played.
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
		_app.haptic(Haptics.Kind.LIGHT)
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
	_app.haptic(Haptics.Kind.HEAVY)
	_confetti.amount = 90 if value < 2048 else 160
	_confetti.restart()


func _on_settled() -> void:
	if not _pending_over or _game_over.is_open:
		return
	await get_tree().create_timer(0.35).timeout
	if not _pending_over or _game_over.is_open:
		return
	_app.sfx.play(Sfx.Kind.LOSE)
	_app.haptic(Haptics.Kind.DOUBLE)
	if not _recorded:
		_recorded = true
		_app.store.record_game(board.size, board.score, board.best_tile)
		_app.save_now()
	var record := board.score > _best_at_start and board.score > 0
	_game_over.present(board.score, board.best_tile, board.move_count, record)


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
	_app.save_now()


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


func _apply_layout(wide: bool) -> void:
	_landscape_mode = wide
	for node in [_header, _actions, _board_view]:
		if node.get_parent():
			node.get_parent().remove_child(node)
	if _side.get_parent():
		_side.get_parent().remove_child(_side)
	if wide:
		_side.add_child(_header)
		_side.add_child(_actions)
		_landscape.add_child(_side)
		_landscape.add_child(_board_view)
	else:
		_portrait.add_child(_header)
		_portrait.add_child(_actions)
		_portrait.add_child(_board_view)
	_portrait.visible = not wide
	_landscape.visible = wide


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
	if dir >= 0:
		request_move(dir)
		get_viewport().set_input_as_handled()


func _try_swipe(delta: Vector2, threshold: float) -> void:
	# _input receives positions already mapped to the base-resolution viewport, so thresholds
	# are DPI-independent.
	if delta.length() < threshold:
		return
	_touch_used = true
	if absf(delta.x) > absf(delta.y):
		request_move(Board.Dir.RIGHT if delta.x > 0 else Board.Dir.LEFT)
	else:
		request_move(Board.Dir.DOWN if delta.y > 0 else Board.Dir.UP)
