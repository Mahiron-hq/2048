class_name App
extends Control
## Root controller: owns persistence, audio, theme and language, and routes between screens.

const TRANSITION_OUT := 0.14
const TRANSITION_IN := 0.24
const SIDE_PADDING := 28.0
const VERTICAL_PADDING := 24.0
## Idle loop pacing while nothing animates; input still wakes the loop immediately.
const IDLE_SLEEP_USEC := 8000

static var instance: App

var store := SaveStore.new()
var sfx := Sfx.new()

var _background := Background.new()
var _safe := MarginContainer.new()
var _screens := Control.new()
var _overlays := Control.new()
var _menu := MenuScreen.new()
var _game := GameScreen.new()
var _settings := SettingsScreen.new()
var _confirm := ConfirmDialog.new()
var _fps_label := Label.new()
var _current: Control
var _settings_return: Control
var _transition: Tween
var _fps_accum := 0.0


func _init() -> void:
	instance = self
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	store.load_from_disk()
	if not store.existed:
		store.theme = SaveStore.ThemeMode.DARK if DisplayServer.is_dark_mode() else SaveStore.ThemeMode.LIGHT
		store.language = I18n.detect()
	I18n.current = store.language
	Palette.current = Palette.make(store.theme == SaveStore.ThemeMode.DARK)

	Engine.max_fps = 0
	OS.low_processor_usage_mode_sleep_usec = IDLE_SLEEP_USEC
	get_tree().set_auto_accept_quit(false)

	add_child(sfx)
	sfx.sound_enabled = store.sound_on
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
	for s in [_menu, _game, _settings]:
		s.visible = false
		_screens.add_child(s)
	add_overlay(_confirm)

	_fps_label.add_theme_font_override("font", Fonts.sans(Fonts.BOLD, true))
	_fps_label.add_theme_font_size_override("font_size", 22)
	_fps_label.add_theme_constant_override("outline_size", 6)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.z_index = 100
	add_child(_fps_label)
	_fps_label.visible = store.show_fps

	_menu.new_game_requested.connect(_on_menu_new_game)
	_menu.continue_requested.connect(_on_menu_continue)
	_menu.settings_requested.connect(_open_settings)
	_game.menu_requested.connect(_to_menu)
	_settings.back_requested.connect(_close_settings)
	get_viewport().size_changed.connect(_apply_safe_area)

	_apply_safe_area()
	# Widgets are constructed before the saved language is known, so refresh their text too.
	_broadcast("_on_language_changed")
	_broadcast("_on_skin_changed")
	sfx.music_enabled = store.music_on
	DisplayRate.request_max()
	_to_menu()


func _exit_tree() -> void:
	# Static caches would otherwise outlive the scene tree and show up as leaks at exit.
	Fonts.clear_cache()
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	var animating := not get_tree().get_processed_tweens().is_empty() or _game.is_celebrating()
	OS.low_processor_usage_mode = not animating and not store.show_fps
	if store.show_fps:
		_fps_accum += delta
		if _fps_accum >= 0.5:
			_fps_accum = 0.0
			var text := "%d FPS · %d Hz" % [Engine.get_frames_per_second(), roundi(DisplayServer.screen_get_refresh_rate())]
			if DisplayRate.max_rate > 0.0:
				text += " (max %d)" % roundi(DisplayRate.max_rate)
			_fps_label.text = text


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_flush_save()
			get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_flush_save()
		NOTIFICATION_APPLICATION_RESUMED:
			DisplayRate.request_max()
			_apply_safe_area()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		_on_back()
		get_viewport().set_input_as_handled()


## Adds a full-screen modal above all screens (outside the safe-area margins).
func add_overlay(c: Control) -> void:
	_overlays.add_child(c)


func is_modal_open() -> bool:
	return _confirm.is_open


## True for the screen being shown or transitioned to; a screen fading out ignores input.
func is_current(screen: Control) -> bool:
	return _current == screen


func confirm(title_key: String, body_key: String, yes_key: String, on_yes: Callable) -> void:
	_confirm.ask(title_key, body_key, yes_key, on_yes)


func save_now() -> void:
	var err := store.save_to_disk()
	if err != OK:
		push_error("Saving failed: %s" % error_string(err))


func feedback_click() -> void:
	sfx.play(Sfx.Kind.CLICK, 1.0, -4.0)
	haptic(6, 0.2)


## Short vibration when enabled. [param amplitude] is 0..1 where the device supports it.
func haptic(duration_ms: int, amplitude: float) -> void:
	if store.haptics_on and OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms, amplitude)


func set_sound(on: bool) -> void:
	store.sound_on = on
	sfx.sound_enabled = on
	save_now()


func set_music(on: bool) -> void:
	store.music_on = on
	sfx.music_enabled = on
	save_now()


func set_haptics(on: bool) -> void:
	store.haptics_on = on
	if on:
		haptic(30, 0.6)
	save_now()


func set_show_fps(on: bool) -> void:
	store.show_fps = on
	_fps_label.visible = on
	_fps_accum = 1.0
	save_now()


## Swaps the palette with a crossfade from a snapshot of the old frame.
func set_theme_mode(mode: SaveStore.ThemeMode) -> void:
	if store.theme == mode:
		return
	store.theme = mode
	save_now()
	var snapshot := TextureRect.new()
	var img := get_viewport().get_texture().get_image()
	if img:
		snapshot.texture = ImageTexture.create_from_image(img)
		snapshot.set_anchors_preset(Control.PRESET_FULL_RECT)
		snapshot.stretch_mode = TextureRect.STRETCH_SCALE
		snapshot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		snapshot.z_index = 90
		add_child(snapshot)
	Palette.current = Palette.make(mode == SaveStore.ThemeMode.DARK)
	_broadcast("_on_skin_changed")
	if snapshot.texture:
		var tw := create_tween()
		tw.tween_property(snapshot, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(snapshot.queue_free)
	else:
		snapshot.queue_free()


func set_language(lang: String) -> void:
	store.language = lang
	I18n.current = lang
	save_now()
	_broadcast("_on_language_changed")


func _broadcast(method: StringName) -> void:
	propagate_call(method, [], true)
	_fps_label.add_theme_color_override("font_color", Palette.current.text)
	_fps_label.add_theme_color_override("font_outline_color", Palette.current.bg_bottom)
	RenderingServer.set_default_clear_color(Palette.current.bg_bottom)


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
	# Tablets and unusually wide screens: keep the phone-width column centered.
	var width := get_viewport_rect().size.x
	var max_content := 760.0
	if width - left - right > max_content:
		var extra := (width - left - right - max_content) * 0.5
		left += extra
		right += extra
	_safe.add_theme_constant_override("margin_top", int(top))
	_safe.add_theme_constant_override("margin_bottom", int(bottom))
	_safe.add_theme_constant_override("margin_left", int(left))
	_safe.add_theme_constant_override("margin_right", int(right))
	_fps_label.position = Vector2(left, maxf(4.0, top - 30.0))


func _show_screen(next: Control) -> void:
	if next == _current:
		return
	var prev := _current
	_current = next
	if _transition:
		_transition.kill()
		for s in [_menu, _game, _settings]:
			if s != next and s != prev:
				s.visible = false
	DisplayServer.screen_set_keep_on(next == _game)
	next.visible = true
	next.modulate.a = 0.0
	next.pivot_offset = _screens.size * 0.5
	next.scale = Vector2(0.97, 0.97)
	_transition = create_tween().set_parallel()
	if prev:
		prev.pivot_offset = _screens.size * 0.5
		_transition.tween_property(prev, "modulate:a", 0.0, TRANSITION_OUT)
		_transition.tween_property(prev, "scale", Vector2(1.02, 1.02), TRANSITION_OUT)
		_transition.chain().tween_callback(prev.hide)
		_transition.chain()
	_transition.tween_property(next, "modulate:a", 1.0, TRANSITION_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition.tween_property(next, "scale", Vector2.ONE, TRANSITION_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _to_menu() -> void:
	_game.close_overlays()
	_game.save_state()
	save_now()
	_menu.refresh(store.best_score, store.has_game())
	_show_screen(_menu)
	_menu.play_intro()


func _on_menu_new_game() -> void:
	if store.has_game() and int(store.game.get("moves", 0)) > 0:
		confirm("CONFIRM_NEW_TITLE", "CONFIRM_NEW_BODY", "YES_NEW", _start_new_game)
	else:
		_start_new_game()


func _start_new_game() -> void:
	_show_screen(_game)
	_game.start_new()


func _on_menu_continue() -> void:
	_show_screen(_game)
	if not _game.resume_saved():
		_game.start_new()


func _open_settings() -> void:
	_settings_return = _current
	_settings.refresh()
	_show_screen(_settings)


func _close_settings() -> void:
	if _settings_return == _game:
		_show_screen(_game)
	else:
		_to_menu()


func _on_back() -> void:
	if _confirm.is_open:
		_confirm.close()
	elif _current == _settings:
		_close_settings()
	elif _current == _game:
		_to_menu()
	else:
		_flush_save()
		get_tree().quit()


func _flush_save() -> void:
	_game.save_state()
	save_now()
