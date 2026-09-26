class_name GameScreen
extends Control
## The play screen: header with scores, action row, board, swipe/keyboard input,
## milestones, undo, and the game-over summary.

signal menu_requested

## Swipe length, in viewport pixels, that commits a move while the finger is still down.
const SWIPE_COMMIT := 44.0
## Shorter flicks still count when the finger lifts quickly.
const SWIPE_FLICK := 22.0
const FLICK_TIME_MS := 220

var board := Board.new()

var _app: App
var _board_view := BoardView.new()
var _score_box := ScoreBox.make("SCORE")
var _best_box := ScoreBox.make("BEST")
var _undo_btn := PillButton.make("UNDO", PillButton.Look.SECONDARY, Icons.Kind.UNDO, 76)
var _new_btn := PillButton.make("NEW", PillButton.Look.SECONDARY, Icons.Kind.RESTART, 76)
var _menu_btn := PillButton.make_icon(Icons.Kind.MENU, 76)
var _hint := SkinLabel.make("HINT", 26, Fonts.MEDIUM, SkinLabel.Role.MUTED)
var _banner := MilestoneBanner.new()
var _confetti := CPUParticles2D.new()
var _game_over := GameOverOverlay.new()

var _touch_index := -1
var _touch_start := Vector2.ZERO
var _touch_time := 0
var _touch_used := false
var _pending_over := false
var _best_at_start := 0
var _record_flashed := false
## False until a game is started or resumed, so an empty board never overwrites a save.
var _active := false


func setup(app: App) -> void:
	_app = app


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 26)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	var logo := TileBadge.make(2048, 112, "2048")
	logo.text_ratio = 0.3
	header.add_child(logo)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	_score_box.custom_minimum_size = Vector2(172, 112)
	_best_box.custom_minimum_size = Vector2(172, 112)
	header.add_child(_score_box)
	header.add_child(_best_box)
	root.add_child(header)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	actions.add_child(_menu_btn)
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(spacer2)
	actions.add_child(_undo_btn)
	actions.add_child(_new_btn)
	root.add_child(actions)

	_board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_board_view)

	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.y = 64
	root.add_child(_hint)

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
	_on_skin_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
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


## Starts a fresh game. With [param intro], tiles pop in.
func start_new(intro := true) -> void:
	board.new_game()
	_active = true
	_game_over.close()
	_pending_over = false
	_best_at_start = _app.store.best_score
	_record_flashed = false
	_refresh_scores(false)
	_board_view.show_board(board, BoardView.Appear.POP if intro else BoardView.Appear.NONE)
	_persist()


## Restores the saved game. Returns false when there is none or it is unreadable.
func resume_saved() -> bool:
	if not _app.store.has_game() or not board.from_dict(_app.store.game):
		return false
	_active = true
	_game_over.close()
	_pending_over = false
	_best_at_start = _app.store.best_score
	_record_flashed = false
	_refresh_scores(false)
	_board_view.show_board(board, BoardView.Appear.POP)
	if not board.can_move():
		_pending_over = true
	return true


func request_move(dir: Board.Dir) -> void:
	if _game_over.is_open or _pending_over:
		return
	var result := board.move(dir)
	if not result.moved:
		_board_view.nudge(dir)
		return
	_board_view.play_move(result)
	_on_moved(result)


func undo() -> void:
	if _game_over.is_open or not board.undo():
		return
	_pending_over = false
	_board_view.show_board(board, BoardView.Appear.FADE)
	_refresh_scores(false)
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
		_app.haptic(12, 0.35)
	if result.gained > 0:
		_score_box.pop_gain(result.gained)
	if _app.store.submit_score(board.score) and _best_at_start > 0 and not _record_flashed:
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
	_app.haptic(45, 0.8)
	_confetti.amount = 90 if value < 2048 else 160
	_confetti.restart()


func _on_settled() -> void:
	if not _pending_over or _game_over.is_open:
		return
	await get_tree().create_timer(0.35).timeout
	if not _pending_over or _game_over.is_open:
		return
	_app.sfx.play(Sfx.Kind.LOSE)
	_app.haptic(60, 0.6)
	var record := board.score > _best_at_start and board.score > 0
	_game_over.present(board.score, board.best_tile, board.move_count, record)


func _refresh_scores(animate: bool) -> void:
	_score_box.set_value(board.score, animate)
	_best_box.set_value(_app.store.best_score, animate)
	_undo_btn.disabled = not board.can_undo()
	var show_hint := board.move_count == 0
	var target := 1.0 if show_hint else 0.0
	if not is_equal_approx(_hint.modulate.a, target):
		create_tween().tween_property(_hint, "modulate:a", target, 0.3)


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


func _accepts_input() -> bool:
	return _app.is_current(self) and not _game_over.is_open and not _app.is_modal_open()


func _try_swipe(delta: Vector2, threshold: float) -> void:
	# _input receives positions already mapped to the 720-wide viewport, so thresholds are DPI-independent.
	var d := delta
	if d.length() < threshold:
		return
	_touch_used = true
	if absf(d.x) > absf(d.y):
		request_move(Board.Dir.RIGHT if d.x > 0 else Board.Dir.LEFT)
	else:
		request_move(Board.Dir.DOWN if d.y > 0 else Board.Dir.UP)
