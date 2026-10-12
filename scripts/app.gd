class_name App
extends Control
## Root controller: owns persistence, audio, theme and language, and routes between screens.

const TRANSITION_OUT := Design.DUR_FAST
const TRANSITION_IN := Design.DUR_BASE + Design.DUR_INSTANT * 0.5
const THEME_FADE := Design.DUR_SLOW + Design.DUR_INSTANT
const SIDE_PADDING := Design.GUTTER
const VERTICAL_PADDING := Design.SPACE_LG
## Idle loop pacing while nothing animates; input still wakes the loop immediately.
const IDLE_SLEEP_USEC := 8000
## Pacing once the screen rests (see REST_AFTER_SEC): the loop alone cost a tenth of a core at 8 ms.
const REST_SLEEP_USEC := 33000
## Stretch base per orientation: the short side is always 720 units, so controls keep their size
## when the device turns.
const BASE_PORTRAIT := Vector2i(720, 1280)
const BASE_LANDSCAPE := Vector2i(1280, 720)
## Short side of the rendered picture per [enum SaveStore.Quality]; smaller screens render natively.
const QUALITY_SHORT_SIDE: Array[int] = [720, 1080, 1440]
## The game screen keeps the display awake this long after the last touch, then the phone's own
## screen timeout applies again.
const KEEP_AWAKE_SEC := 120.0
## Play time stops counting once this long has passed without a move.
const PLAY_IDLE_SEC := 60.0
## After this long with no touch and nothing animating the game stops asking for a high refresh
## rate, so a still screen runs at the system's idle rate; the next touch asks again.
const REST_AFTER_SEC := 2.0
## Frame rate while only slow ambient animations run (see [method add_ambient]): they look the
## same at this rate, and drawing an untouched new board at 120 fps cost most of a core.
const AMBIENT_FPS := 30

static var instance: App
## Message for the next app instance to show on its menu, e.g. after an import reload.
static var pending_toast := ""

## The measurement build keeps its own file, so even run over an installed game it never reads
## or writes the player's save.
var store := SaveStore.new("user://bench.json" if OS.has_feature("bench") else SaveStore.DEFAULT_PATH)
var sfx := Sfx.new()

var _background := Background.new()
var _safe := MarginContainer.new()
var _screens := Control.new()
var _overlays := Control.new()
var _menu := MenuScreen.new()
var _game := GameScreen.new()
var _settings := SettingsScreen.new()
var _stats := StatsScreen.new()
var _confirm := ConfirmDialog.new()
var _picker := SizePicker.new()
var _toast := Toast.new()
var _reset := ResetDialog.new()
var _about := AboutScreen.new()
## Board size for the next new game, remembered between launches.
var selected_size := Board.DEFAULT_SIZE
## Play time not yet added to the statistics.
var _play_time := 0.0
## Seconds since the last touch or key press, for the screen keep-awake.
var _since_input := 0.0
var _still := 0.0
var _ambient: Array[Tween] = []
## Seconds since the last move (or since play resumed), for the play-time clock.
var _since_move := 0.0
var _keep_awake := false
## Outcome of reading the save at launch, shown once on the menu when it was not clean.
var _load_result := SaveStore.Load.OK
## Text of the last save handed to the writer; an identical one is not written again.
var _saved_text := ""
## Set while the app reloads after an import: the state on screen must not be saved over it.
var _discarding := false
## Result of the background write in flight, read once it has completed.
var _save_error := OK
## Background save in flight (WorkerThreadPool task id), or -1.
var _save_task := -1
## Newer save text waiting for the one in flight to finish.
var _queued_save := ""
## Seconds until a requested (debounced) save runs; negative when none is pending.
var _save_countdown := -1.0

## Gameplay changes are batched: a burst of moves produces one write.
const SAVE_DEBOUNCE := 0.75
var _focused := true
var _fps_label := Label.new()
var _current: Control
var _settings_return: Control
var _transition: Tween
var _theme_snapshot: TextureRect
var _theme_fade: Tween
## Built once per palette: a fresh Theme on every switch made each control re-read its look.
var _themes := {}
## Hidden screens and the broadcasts they still owe, run when they are shown. Restyling and
## relaying out all five screens made every theme, language or text size switch hitch.
var _stale := {}
var _fps_accum := 0.0


func _init() -> void:
	instance = self
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	# One line in the log tells which hint engine this build runs; the emulator check reads it.
	print("2048 Merge %s: hints on the %s engine" % [ProjectSettings.get_setting("application/config/version"),
			"native" if ClassDB.class_exists(&"HintEngine") else "GDScript"])
	_load_result = store.load_from_disk()
	if not store.existed:
		store.language = I18n.detect()
	elif _load_result == SaveStore.Load.OK:
		# Nothing to write until something changes; a recovered state is written back at once.
		_saved_text = store.serialize()
	selected_size = store.board_size
	I18n.current = store.language
	Design.text_scale = _wanted_text_scale()
	Motion.apply(store.reduce_motion)
	Palette.current = Palette.make(_wants_dark())
	DisplayServer.set_system_theme_change_callback(_on_system_theme_changed)

	OS.low_processor_usage_mode_sleep_usec = IDLE_SLEEP_USEC
	get_tree().set_auto_accept_quit(false)

	add_child(sfx)
	sfx.sound_enabled = store.sound_on
	sfx.set_sound_volume(store.sound_volume)
	sfx.set_music_volume(store.music_volume, false)
	add_child(_background)
	_safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_safe)
	_screens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(_screens)
	_overlays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlays)

	_game.setup(self)
	_settings.setup(self)
	_stats.setup(self)
	_about.setup(self)
	for s in [_menu, _game, _settings, _stats, _about]:
		s.visible = false
		_screens.add_child(s)
	add_overlay(_confirm)
	add_overlay(_picker)
	add_overlay(_reset)
	add_overlay(_toast)
	_reset.confirmed.connect(_on_reset_confirmed)

	_fps_label.add_theme_font_override("font", Fonts.sans(Design.WEIGHT_BOLD, true))
	_fps_label.add_theme_constant_override("outline_size", int(Design.SPACE_XS))
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.z_index = 100
	add_child(_fps_label)
	_fps_label.visible = store.show_fps

	_menu.new_game_requested.connect(_on_menu_new_game)
	_menu.continue_requested.connect(_on_menu_continue)
	_menu.settings_requested.connect(_open_settings)
	_menu.stats_requested.connect(_open_stats)
	_menu.size_menu_requested.connect(func(anchor: Rect2) -> void: _picker.open_at(anchor, selected_size))
	_picker.chosen.connect(_on_size_chosen)
	_game.menu_requested.connect(_to_menu)
	_settings.back_requested.connect(_close_settings)
	_settings.about_requested.connect(_open_about)
	_about.back_requested.connect(_close_about)
	_stats.back_requested.connect(_to_menu)
	get_viewport().size_changed.connect(_on_viewport_resized)

	_update_content_scale()
	_apply_safe_area()
	# Widgets are constructed before the saved language is known, so refresh their text too.
	_broadcast("_on_language_changed")
	_broadcast("_on_skin_changed")
	sfx.music_enabled = store.music_on
	DisplayRate.apply(store.fps_limit)
	_to_menu()
	match _load_result:
		SaveStore.Load.RECOVERED:
			toast("SAVE_RECOVERED")
		SaveStore.Load.LOST:
			toast("SAVE_LOST")
	if not pending_toast.is_empty():
		toast(pending_toast)
		pending_toast = ""
	if OS.has_feature("bench"):
		# The measurement builds only: tools/device_bench.py reads its log.
		add_child(load("res://tests/bench/driver.gd").new())
	# Launch frames are slow anyway; better here than in the middle of a game.
	_game.prime_overlays()
	_confirm.prime()


func _exit_tree() -> void:
	if not _discarding:
		_flush_save()
	# Static caches would otherwise outlive the scene tree and show up as leaks at exit.
	Fonts.clear_cache()
	TileArt.clear_cache()
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	if _save_countdown >= 0.0:
		_save_countdown -= delta
		if _save_countdown < 0.0:
			save_now()
	_pump_saves()
	_since_input += delta
	_since_move += delta
	if _focused and _current == _game and _game.is_playing() and _since_move <= PLAY_IDLE_SEC:
		_play_time += delta
	_update_keep_awake()
	var tweens := get_tree().get_processed_tweens()
	var animating := not tweens.is_empty() or _game.is_celebrating()
	var ambient := animating and not _game.is_celebrating() and _only_ambient(tweens)
	OS.low_processor_usage_mode = not animating and not store.show_fps
	_still = 0.0 if animating and not ambient else _still + delta
	_rest(_still >= REST_AFTER_SEC and not store.show_fps)
	var cap := store.fps_limit
	if ambient and not store.show_fps and (cap == 0 or cap > AMBIENT_FPS):
		cap = AMBIENT_FPS
	if Engine.max_fps != cap:
		Engine.max_fps = cap
	if store.show_fps:
		_fps_accum += delta
		if _fps_accum >= 0.5:
			_fps_accum = 0.0
			_fps_label.text = _fps_text()


## Overlay line: measured FPS, the display's current rate, the cap, and the ceilings that apply.
func _fps_text() -> String:
	var text := "%d FPS · %d Hz" % [Engine.get_frames_per_second(), roundi(DisplayServer.screen_get_refresh_rate())]
	if store.fps_limit > 0:
		text += " · cap %d" % store.fps_limit
	var top := roundi(DisplayRate.max_rate())
	var panel := roundi(DisplayRate.panel_max())
	if panel > top:
		text += " (max %d, panel %d)" % [top, panel]
	elif top > 0:
		text += " (max %d)" % top
	return text


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_flush_save()
			get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
			_flush_save()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true
			_follow_system_theme()
		NOTIFICATION_APPLICATION_RESUMED:
			_focused = true
			_since_input = 0.0
			_since_move = 0.0
			_follow_system_theme()
			# The system refresh rate setting may have changed while the game was away.
			DisplayRate.apply(store.fps_limit)
			_apply_safe_area()
			# The system vibration switch may have changed while the game was away.
			Haptics.refresh_system_state()
			_settings.refresh_haptics_note()
			# So may the font size and the "remove animations" setting.
			_follow_system_text_and_motion()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventKey or event is InputEventMouseButton:
		_since_input = 0.0
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventKey 			or event is InputEventMouseButton or event is InputEventMouseMotion:
		_still = 0.0
		_rest(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		_on_back()
		get_viewport().set_input_as_handled()


## Marks [param tween] as ambient: a slow loop such as the swipe hint's breathing. While nothing
## else animates the game draws at AMBIENT_FPS and the display may rest.
func add_ambient(tween: Tween) -> void:
	_ambient = _ambient.filter(func(t: Tween) -> bool: return t.is_valid())
	_ambient.append(tween)


func _only_ambient(tweens: Array[Tween]) -> bool:
	for t in tweens:
		if not _ambient.has(t):
			return false
	return true


func _rest(resting: bool) -> void:
	DisplayRate.rest(resting)
	OS.low_processor_usage_mode_sleep_usec = REST_SLEEP_USEC if resting else IDLE_SLEEP_USEC


## A move was played or undone, or a game started or resumed: the play-time clock runs again.
func note_move() -> void:
	_since_move = 0.0


## Holds the display awake on the game screen until the player has left it untouched for
## KEEP_AWAKE_SEC; the phone's own timeout takes over after that.
func _update_keep_awake() -> void:
	var want := _current == _game and _since_input < KEEP_AWAKE_SEC
	if want != _keep_awake:
		_keep_awake = want
		DisplayServer.screen_set_keep_on(want)


## Adds a full-screen modal above all screens (outside the safe-area margins).
func add_overlay(c: Control) -> void:
	_overlays.add_child(c)


func is_modal_open() -> bool:
	return _confirm.is_open or _picker.is_open or _reset.is_open


## True for the screen being shown or transitioned to; a screen fading out ignores input.
func is_current(screen: Control) -> bool:
	return _current == screen


## Shows a short message that fades away on its own.
func toast(key: String) -> void:
	_toast.show_message(key)


func confirm(title_key: String, body_key: String, yes_key: String, on_yes: Callable) -> void:
	_confirm.ask(title_key, body_key, yes_key, on_yes)


## Saves the game, on a worker thread: a slow flash write can take seconds on a busy phone.
## [param sync] writes on the spot, for going to the background or quitting.
func save_now(sync := false) -> void:
	_save_countdown = -1.0
	var text := store.serialize()
	if text == _saved_text and _queued_save.is_empty():
		return
	_saved_text = text
	if sync:
		_wait_for_save()
		_queued_save = ""
		_report_save(store.write_text(text))
		return
	if _save_task >= 0 and not WorkerThreadPool.is_task_completed(_save_task):
		_queued_save = text
		return
	_wait_for_save()
	_save_task = WorkerThreadPool.add_task(_write_save.bind(text), false, "save")


func _write_save(text: String) -> void:
	_save_error = store.write_text(text)


## Main thread only. A failed write forgets the saved text, so the same state is written again.
func _report_save(err: Error) -> void:
	if err != OK:
		_saved_text = ""
		push_error("Saving failed: %s" % error_string(err))


func _wait_for_save() -> void:
	if _save_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_save_task)
		_save_task = -1
		_report_save(_save_error)
		_save_error = OK


## Schedules a save; requests within SAVE_DEBOUNCE collapse into one write.
func request_save() -> void:
	if _save_countdown < 0.0:
		_save_countdown = SAVE_DEBOUNCE


func _pump_saves() -> void:
	if _save_task < 0 or not WorkerThreadPool.is_task_completed(_save_task):
		return
	_wait_for_save()
	if not _queued_save.is_empty():
		var text := _queued_save
		_queued_save = ""
		_save_task = WorkerThreadPool.add_task(_write_save.bind(text), false, "save")


func feedback_click() -> void:
	sfx.play(Sfx.Kind.CLICK, 1.0, -4.0)
	haptic(Haptics.Kind.TICK)


## Tactile feedback of [param kind] when vibration is enabled.
func haptic(kind: Haptics.Kind) -> void:
	if _haptics_allowed():
		Haptics.play(kind)


## Merge buzz scaled to the value of the merged tiles, when vibration is enabled.
func haptic_merge(value: int) -> void:
	if _haptics_allowed():
		Haptics.merge(value)


func haptic_game_over() -> void:
	if _haptics_allowed():
		Haptics.game_over()


func _haptics_allowed() -> bool:
	return store.haptics_on and OS.has_feature("mobile")


## Adds play time accumulated since the last flush to the statistics.
func flush_play_time() -> void:
	if _play_time > 0.0:
		store.add_play_time(_game.board.size, _play_time)
		_play_time = 0.0


func set_undo_limit(limit: int) -> void:
	store.undo_limit = limit
	_game.set_undo_limit(limit)
	save_now()


func set_sound(on: bool) -> void:
	store.sound_on = on
	sfx.sound_enabled = on
	save_now()


## Stores the effects volume step; the click that follows previews the new level.
func set_sound_volume(step: int) -> void:
	store.sound_volume = step
	sfx.set_sound_volume(step)
	feedback_click()
	save_now()


func set_music_volume(step: int) -> void:
	store.music_volume = step
	sfx.set_music_volume(step)
	feedback_click()
	save_now()


func set_music(on: bool) -> void:
	store.music_on = on
	sfx.music_enabled = on
	save_now()


func set_haptics(on: bool) -> void:
	store.haptics_on = on
	if on:
		haptic(Haptics.Kind.LIGHT)
	save_now()


func set_hints(on: bool) -> void:
	store.hints_on = on
	_game.set_hints_enabled(on)
	save_now()


func set_show_fps(on: bool) -> void:
	store.show_fps = on
	_fps_label.visible = on
	_fps_accum = 1.0
	save_now()


## Caps the frame rate at [param limit] (0: no cap) and asks the display for a matching rate.
func set_fps_limit(limit: int) -> void:
	store.fps_limit = limit
	DisplayRate.apply(limit)
	_fps_accum = 1.0
	save_now()


## Stores the theme choice and crossfades to it if the look changes.
func set_theme_mode(mode: SaveStore.ThemeMode) -> void:
	if store.theme == mode:
		return
	store.theme = mode
	save_now()
	_apply_palette()


## Picture quality: renders at a lower resolution to save power, or up to 2K.
func set_quality(quality: SaveStore.Quality) -> void:
	store.quality = quality
	save_now()
	_update_content_scale()


## Resolution the picture is rendered at, in pixels.
func render_resolution() -> Vector2i:
	var vp := get_viewport()
	if vp is SubViewport:
		return (vp as SubViewport).size
	var window := vp as Window
	if window.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT:
		return window.content_scale_size
	return window.size


func _wants_dark() -> bool:
	match store.theme:
		SaveStore.ThemeMode.DARK:
			return true
		SaveStore.ThemeMode.LIGHT:
			return false
	return DisplayServer.is_dark_mode()


func _on_system_theme_changed() -> void:
	_follow_system_theme.call_deferred()


func _follow_system_theme() -> void:
	if store.theme == SaveStore.ThemeMode.SYSTEM:
		_apply_palette()


## Swaps the palette when the wanted look differs, crossfading from a snapshot of the old frame.
func _apply_palette() -> void:
	var dark := _wants_dark()
	if dark == Palette.current.dark:
		return
	# While a crossfade runs its snapshot keeps fading over the new look; reading the frame back
	# from the GPU again would only make quick taps stutter.
	if _theme_fade and _theme_fade.is_valid():
		Palette.current = Palette.make(dark)
		_broadcast("_on_skin_changed")
		return
	_clear_theme_fade()
	# The headless test runs render nothing to capture.
	var img := get_viewport().get_texture().get_image() if DisplayServer.get_name() != "headless" else null
	if img:
		_theme_snapshot = TextureRect.new()
		_theme_snapshot.texture = ImageTexture.create_from_image(img)
		# The image is in physical pixels; keeping its size as the minimum would overflow the canvas.
		_theme_snapshot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_theme_snapshot.stretch_mode = TextureRect.STRETCH_SCALE
		_theme_snapshot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_theme_snapshot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_theme_snapshot.z_index = 90
		add_child(_theme_snapshot)
	Palette.current = Palette.make(dark)
	_broadcast("_on_skin_changed")
	if _theme_snapshot:
		_theme_fade = create_tween()
		_theme_fade.tween_property(_theme_snapshot, "modulate:a", 0.0, THEME_FADE).set_trans(Tween.TRANS_SINE)
		_theme_fade.tween_callback(_clear_theme_fade)


func _clear_theme_fade() -> void:
	if _theme_fade:
		_theme_fade.kill()
		_theme_fade = null
	if _theme_snapshot:
		_theme_snapshot.queue_free()
		_theme_snapshot = null


## Strength of the move hint.
func set_hint_level(level: SaveStore.HintLevel) -> void:
	store.hint_level = level
	save_now()


## Text size: a fixed step or the phone's font size; relays out every screen.
func set_text_size(size: SaveStore.TextSize) -> void:
	store.text_size = size
	save_now()
	_apply_text_scale()


func set_reduce_motion(mode: SaveStore.ReduceMotion) -> void:
	store.reduce_motion = mode
	save_now()
	Motion.apply(mode)


## Opens the two-step reset for [param scope].
func ask_reset(scope: ResetDialog.Scope) -> void:
	_reset.ask(scope)


func _on_reset_confirmed(scope: ResetDialog.Scope, size: int) -> void:
	if scope != ResetDialog.Scope.RECORDS:
		flush_play_time()
		store.reset_stats(size)
	if scope != ResetDialog.Scope.STATS:
		store.reset_records(size)
	_game.on_records_changed()
	save_now()
	toast("RESET_DONE")


## Asks where to save a copy of the progress (records, statistics, settings, the current game).
func export_progress() -> void:
	flush_play_time()
	_game.save_state()
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		toast("EXPORT_FAILED")
		return
	var file_name := "2048-merge-progress-%s.json" % Time.get_date_string_from_system()
	DisplayServer.file_dialog_show(I18n.t("EXPORT_PROGRESS"), OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS), file_name,
			false, DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray(["*.json;JSON"]),
			func(ok: bool, paths: PackedStringArray, _filter: int) -> void: _write_export.call_deferred(ok, paths))


func _write_export(ok: bool, paths: PackedStringArray) -> void:
	if not ok or paths.is_empty():
		return
	var f := FileAccess.open(paths[0], FileAccess.WRITE)
	if f == null:
		toast("EXPORT_FAILED")
		return
	f.store_string(JSON.stringify(store.to_dict(), "\t"))
	var err := f.get_error()
	f.close()
	toast("EXPORT_DONE" if err == OK else "EXPORT_FAILED")


## Asks for an exported file and, after two confirmations, replaces everything with it.
func import_progress() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		toast("IMPORT_FAILED")
		return
	DisplayServer.file_dialog_show(I18n.t("IMPORT_PROGRESS"), OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS), "",
			false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(["*.json;JSON"]),
			func(ok: bool, paths: PackedStringArray, _filter: int) -> void: _read_import.call_deferred(ok, paths))


func _read_import(ok: bool, paths: PackedStringArray) -> void:
	if not ok or paths.is_empty():
		return
	var data := SaveStore.parse_export(FileAccess.get_file_as_string(paths[0]))
	if data.is_empty():
		toast("IMPORT_FAILED")
		return
	var preview := SaveStore.new("user://import_preview.json")
	preview.apply_dict(data)
	var totals := preview.stats_for(0)
	var summary := I18n.t("IMPORT_SURE_BODY") % [I18n.tn("N_GAMES", totals.games), I18n.number(totals.best_score)]
	_reset.ask_import(summary, _apply_import.bind(JSON.stringify(data)))


## Writes the imported progress as the save and restarts the app from it.
func _apply_import(text: String) -> void:
	_wait_for_save()
	_queued_save = ""
	var err := store.write_text(text)
	if err != OK:
		_report_save(err)
		toast("IMPORT_FAILED")
		return
	_discarding = true
	# A static survives the reload, so the new app instance can greet with it.
	pending_toast = "IMPORT_DONE"
	get_tree().reload_current_scene()


func _wanted_text_scale() -> float:
	match store.text_size:
		SaveStore.TextSize.NORMAL:
			return 1.0
		SaveStore.TextSize.LARGE:
			return 1.15
		SaveStore.TextSize.XLARGE:
			return AndroidBridge.MAX_FONT_SCALE
	return AndroidBridge.font_scale()


func _apply_text_scale() -> void:
	var scale := _wanted_text_scale()
	if is_equal_approx(scale, Design.text_scale):
		return
	Design.text_scale = scale
	_broadcast("_on_skin_changed")
	_broadcast("_on_language_changed")


func _follow_system_text_and_motion() -> void:
	if store.text_size == SaveStore.TextSize.SYSTEM:
		_apply_text_scale()
	if store.reduce_motion == SaveStore.ReduceMotion.SYSTEM:
		Motion.apply(store.reduce_motion)


func set_language(lang: String) -> void:
	store.language = lang
	I18n.current = lang
	save_now()
	_broadcast("_on_language_changed")


func _broadcast(method: StringName) -> void:
	var live: Array[Control] = [_background, _overlays, _fps_label]
	for s: Control in [_menu, _game, _settings, _stats, _about]:
		if s.visible:
			live.append(s)
		else:
			var owed: Array = _stale.get_or_add(s, [])
			if not owed.has(method):
				owed.append(method)
	if method == &"_on_skin_changed":
		var t := _theme_for_palette()
		for c in live:
			c.theme = t
	for c in live:
		c.propagate_call(method, [], true)
	_fps_label.add_theme_font_size_override("font_size", Design.ts(Design.TEXT_CAPTION))
	_fps_label.add_theme_color_override("font_color", Palette.current.text)
	_fps_label.add_theme_color_override("font_outline_color", Palette.current.bg)
	RenderingServer.set_default_clear_color(Palette.current.bg_deep)


func _theme_for_palette() -> Theme:
	var dark := Palette.current.dark
	if not _themes.has(dark):
		_themes[dark] = Design.make_theme()
	return _themes[dark]


## Brings a screen up to date with the broadcasts it missed while hidden; call before showing it.
func _refresh_stale(screen: Control) -> void:
	var owed: Array = _stale.get(screen, [])
	if owed.is_empty():
		return
	_stale.erase(screen)
	if owed.has(&"_on_skin_changed"):
		screen.theme = _theme_for_palette()
	for method: StringName in owed:
		screen.propagate_call(method, [], true)


func _on_viewport_resized() -> void:
	_update_content_scale()
	_apply_safe_area()


## Lays the UI out on a 720-unit short side and renders it at the chosen quality: natively, or
## into a smaller canvas that the window scales up.
func _update_content_scale() -> void:
	var window := get_window()
	if window == null or window != get_tree().root:
		return
	var px := Vector2(window.size)
	if px.x < 1.0 or px.y < 1.0:
		return
	var base := BASE_LANDSCAPE if px.x > px.y * 1.1 else BASE_PORTRAIT
	var target := float(QUALITY_SHORT_SIDE[store.quality])
	if minf(px.x, px.y) <= target:
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		window.content_scale_size = base
		window.content_scale_factor = 1.0
		return
	# Same layout units as the canvas mode gives, drawn into a canvas that much smaller.
	var render := target / minf(px.x, px.y)
	var stretch := minf(px.x / base.x, px.y / base.y)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_size = Vector2i((px * render).round())
	window.content_scale_factor = stretch * render


func _apply_safe_area() -> void:
	var top := VERTICAL_PADDING
	var bottom := VERTICAL_PADDING
	var left := SIDE_PADDING
	var right := SIDE_PADDING
	if OS.has_feature("mobile"):
		var win := Vector2(DisplayServer.window_get_size())
		var safe := DisplayServer.get_display_safe_area()
		var vp := get_viewport_rect().size
		if win.x > 0 and win.y > 0 and safe.size.x > 0:
			var k := vp / win
			top += safe.position.y * k.y
			left += safe.position.x * k.x
			right += maxf(0.0, win.x - safe.end.x) * k.x
			bottom += maxf(0.0, win.y - safe.end.y) * k.y
	# Portrait tablets keep a phone-width column; landscape is only clamped on extreme ratios.
	var vp_size := get_viewport_rect().size
	var width := vp_size.x
	var max_content := 760.0 if vp_size.x <= vp_size.y * 1.1 else vp_size.y * 2.3
	if width - left - right > max_content:
		var extra := (width - left - right - max_content) * 0.5
		left += extra
		right += extra
	_safe.add_theme_constant_override("margin_top", int(top))
	_safe.add_theme_constant_override("margin_bottom", int(bottom))
	_safe.add_theme_constant_override("margin_left", int(left))
	_safe.add_theme_constant_override("margin_right", int(right))
	# Landscape keeps the logo top-left, so the overlay goes bottom-right.
	if vp_size.x > vp_size.y * 1.1:
		_fps_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_fps_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_fps_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_fps_label.offset_right = -right
		_fps_label.offset_left = -right
		_fps_label.offset_bottom = -maxf(Design.SPACE_2XS, bottom - _fps_label.get_combined_minimum_size().y)
		_fps_label.offset_top = _fps_label.offset_bottom
	else:
		_fps_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_fps_label.grow_horizontal = Control.GROW_DIRECTION_END
		_fps_label.grow_vertical = Control.GROW_DIRECTION_END
		# Above the content, in the status bar's band where there is one.
		var h := _fps_label.get_combined_minimum_size().y
		_fps_label.position = Vector2(left, maxf(0.0, top - h))
		_fps_label.size = Vector2.ZERO


func _show_screen(next: Control) -> void:
	if next == _current:
		return
	var prev := _current
	_current = next
	if _transition:
		_transition.kill()
		for s in [_menu, _game, _settings, _stats, _about]:
			if s != next and s != prev:
				s.visible = false
	_since_input = 0.0
	_update_keep_awake()
	_refresh_stale(next)
	next.visible = true
	next.modulate.a = 0.0
	next.pivot_offset = _screens.size * 0.5
	# With reduced motion screens only cross-fade.
	var still := Motion.reduced()
	next.scale = Vector2.ONE if still else Vector2(0.97, 0.97)
	_transition = create_tween().set_parallel()
	if prev:
		prev.pivot_offset = _screens.size * 0.5
		_transition.tween_property(prev, "modulate:a", 0.0, TRANSITION_OUT)
		_transition.tween_property(prev, "scale", Vector2.ONE if still else Vector2(1.02, 1.02), TRANSITION_OUT)
		_transition.chain().tween_callback(prev.hide)
		_transition.chain()
	_transition.tween_property(next, "modulate:a", 1.0, TRANSITION_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition.tween_property(next, "scale", Vector2.ONE, TRANSITION_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _to_menu() -> void:
	_game.close_overlays()
	flush_play_time()
	_game.save_state()
	save_now()
	_refresh_menu()
	_show_screen(_menu)
	_menu.play_intro()


func _on_menu_new_game() -> void:
	if _saved_game_in_play():
		confirm("CONFIRM_NEW_TITLE", "CONFIRM_NEW_BODY", "YES_NEW", _start_new_game)
	else:
		_start_new_game()


## A saved game with moves that is not lost yet: replacing it loses progress.
func _saved_game_in_play() -> bool:
	if not store.has_game():
		return false
	var saved := Board.new(1)
	return saved.from_dict(store.game) and saved.move_count > 0 and saved.can_move()


func _start_new_game() -> void:
	_show_screen(_game)
	_game.start_new(selected_size)


func _refresh_menu() -> void:
	_menu.refresh(store.best_for(selected_size), selected_size, store.game_size())


func _on_size_chosen(n: int) -> void:
	selected_size = n
	store.board_size = n
	request_save()
	_refresh_menu()


func _open_stats() -> void:
	_stats.refresh()
	_show_screen(_stats)


func _on_menu_continue() -> void:
	_show_screen(_game)
	if not _game.resume_saved():
		_game.start_new()


func _open_settings() -> void:
	_settings_return = _current
	_settings.refresh()
	_show_screen(_settings)


func _open_about() -> void:
	_about.refresh()
	_show_screen(_about)


func _close_about() -> void:
	_show_screen(_settings)


func _close_settings() -> void:
	if _settings_return == _game:
		_show_screen(_game)
	else:
		_to_menu()


func _on_back() -> void:
	if _picker.is_open:
		_picker.close()
	elif _confirm.is_open:
		_confirm.close()
	elif _reset.is_open:
		_reset.close()
	elif _current == _about:
		_close_about()
	elif _current == _stats:
		_to_menu()
	elif _current == _settings:
		_close_settings()
	elif _current == _game:
		_to_menu()
	else:
		_flush_save()
		# Android keeps a backed-out app alive rather than ending it; doing the same makes the
		# next launch instant.
		if not AndroidBridge.move_to_background():
			get_tree().quit()


func _flush_save() -> void:
	flush_play_time()
	_game.save_state()
	save_now(true)
