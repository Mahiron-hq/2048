extends SceneTree
## Renders the store promo video frames (1080x1920, 30 fps) with captions in one language:
## godot --path . --fixed-fps 30 --script res://tools/make_promo_video.gd -- ru
## Frames go to build/promo/<lang>/; tools/make_promo_video.py adds the music and encodes them.

const SIZE := Vector2i(1080, 1920)
const FPS := 30
const LENGTH := 30.0
const SAVE := "user://promo_save.json"
## The phone screen inside the frame, as a share of the frame width.
const SCREEN_SCALE := 0.74
const SCREEN_TOP := 380.0
const SCREEN_RADIUS := 56.0

const CAPTIONS := {
	"ru": [
		["2048 Merge", "Спокойная головоломка слияний"],
		["Свайп — и плитки скользят", "Плавно, отзывчиво и без рекламы"],
		["Праздник на каждой вехе", "128, 256 … 2048 и дальше"],
		["Подсказка лучшего хода", "Лампочка подскажет, ход — за вами"],
		["Отмена до пяти ходов", "Ход проигрывается назад"],
		["Светлая и тёмная темы", "Поля от 3×3 до 6×6"],
	],
	"en": [
		["2048 Merge", "A calm, polished number puzzle"],
		["Swipe and the tiles glide", "Smooth, responsive and ad-free"],
		["Every milestone celebrated", "128, 256 … 2048 and beyond"],
		["Hints for the best move", "The bulb suggests, you decide"],
		["Undo up to five moves", "Each move plays backwards"],
		["Light and dark themes", "Boards from 3×3 to 6×6"],
	],
}
const END_LINE := {"ru": "Без рекламы  ·  Офлайн  ·  Авторская музыка", "en": "No ads  ·  Offline  ·  Original soundtrack"}

var lang := "ru"
var app: App
var _stage: SubViewport
var _app_vp: SubViewport
var _bg := ColorRect.new()
var _shadow := Panel.new()
var _screen := TextureRect.new()
var _title := Label.new()
var _subtitle := Label.new()
var _end := Control.new()
var _fade := ColorRect.new()
var _frame := 0
var _out := ""


func _initialize() -> void:
	OS.low_processor_usage_mode = false
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		lang = args[0]
	_out = ProjectSettings.globalize_path("res://build/promo/%s/" % lang)
	DirAccess.make_dir_recursive_absolute(_out)
	for f in DirAccess.get_files_at(_out):
		DirAccess.remove_absolute(_out + f)
	DirAccess.remove_absolute(SAVE)
	_build()
	_run.call_deferred()
	_record.call_deferred()


func _build() -> void:
	_stage = SubViewport.new()
	_stage.size = SIZE
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_stage)
	var stage := Control.new()
	stage.size = Vector2(SIZE)
	_stage.add_child(stage)

	_app_vp = SubViewport.new()
	_app_vp.size = SIZE
	_app_vp.size_2d_override = Vector2i(720, 1280)
	_app_vp.size_2d_override_stretch = true
	_app_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_app_vp)
	app = load("res://scenes/main.tscn").instantiate()
	app.store = SaveStore.new(SAVE)
	_app_vp.add_child(app)

	_bg.size = Vector2(SIZE)
	stage.add_child(_bg)
	var screen_size := Vector2(SIZE) * SCREEN_SCALE
	var screen_pos := Vector2((SIZE.x - screen_size.x) * 0.5, SCREEN_TOP)
	_shadow.position = screen_pos
	_shadow.size = screen_size
	stage.add_child(_shadow)
	_screen.texture = _app_vp.get_texture()
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_SCALE
	_screen.position = screen_pos
	_screen.size = screen_size
	_screen.pivot_offset = screen_size * 0.5
	var mask := ShaderMaterial.new()
	mask.shader = Shader.new()
	mask.shader.code = """
shader_type canvas_item;
uniform vec2 box;
uniform float radius;
void fragment() {
	vec2 p = abs(UV * box - box * 0.5) - (box * 0.5 - radius);
	float d = length(max(p, 0.0)) - radius;
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= clamp(0.5 - d, 0.0, 1.0);
}
"""
	mask.set_shader_parameter("box", screen_size)
	mask.set_shader_parameter("radius", SCREEN_RADIUS)
	_screen.material = mask
	stage.add_child(_screen)

	for l: Label in [_title, _subtitle]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(SIZE.x, 0)
		stage.add_child(l)
	_title.add_theme_font_override("font", Fonts.sans(Design.WEIGHT_HEAVY))
	_title.add_theme_font_size_override("font_size", 76)
	_title.position.y = 150
	_subtitle.add_theme_font_override("font", Fonts.sans(Design.WEIGHT_MEDIUM))
	_subtitle.add_theme_font_size_override("font_size", 42)
	_subtitle.position.y = 262

	_end.size = Vector2(SIZE)
	_end.modulate.a = 0.0
	stage.add_child(_end)
	_fade.size = Vector2(SIZE)
	stage.add_child(_fade)
	_skin()


## Stage colors follow the game's palette; with [param fade], over the game's own crossfade.
func _skin(fade := 0.0) -> void:
	var p := Palette.current
	_fade.color = Color(p.board, _fade.color.a)
	var box := Design.surface_box(p.bg, SCREEN_RADIUS, 2)
	box.shadow_size = 48
	box.shadow_offset = Vector2(0, 24)
	_shadow.add_theme_stylebox_override("panel", box)
	if fade <= 0.0:
		_bg.color = p.board
		_title.add_theme_color_override("font_color", p.text)
		_subtitle.add_theme_color_override("font_color", p.text_secondary)
		return
	var tw := _bg.create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tw.tween_property(_bg, "color", p.board, fade)
	tw.tween_property(_title, "theme_override_colors/font_color", p.text, fade)
	tw.tween_property(_subtitle, "theme_override_colors/font_color", p.text_secondary, fade)


func _record() -> void:
	var total := int(LENGTH * FPS)
	while _frame < total:
		await RenderingServer.frame_post_draw
		_stage.get_texture().get_image().save_jpg(_out + "%04d.jpg" % _frame, 0.96)
		_frame += 1
	print("frames ", _frame)
	quit(0)


func _run() -> void:
	var g := app._game
	app.sfx.music_enabled = false
	app.set_language(lang)
	app.set_theme_mode(SaveStore.ThemeMode.DARK)
	app.set_undo_limit(5)
	_skin()
	_fade.color.a = 1.0
	_caption(0)
	app._to_menu()
	_tween(_fade, "color:a", 0.0, 0.8)
	_push_in(4.0)
	await _at(4.0)

	_caption(1)
	app._start_new_game()
	g.board.rng.seed = 2048
	g._board_view.hide_hint(true)
	_push_in(7.0)
	await _at(4.9)
	var dirs := [Board.Dir.LEFT, Board.Dir.DOWN, Board.Dir.RIGHT, Board.Dir.DOWN, Board.Dir.LEFT, Board.Dir.DOWN]
	var t := 4.9
	while t < 10.6:
		g.request_move(_best_dir(g.board, dirs))
		t += 0.62
		await _at(t)
	await _at(11.0)

	_caption(2)
	_load(g, [[1024, 1024, 64, 8], [256, 128, 32, 4], [16, 8, 4, 2], [4, 2, 0, 0]], 19620)
	_push_in(4.0)
	await _at(12.0)
	g.request_move(Board.Dir.LEFT)
	await _at(15.0)

	_caption(3)
	_load(g, [[2, 8, 32, 128], [4, 16, 64, 256], [2, 4, 8, 512], [0, 2, 4, 16]], 6412)
	_push_in(4.5)
	g._idle = GameScreen.HINT_IDLE - 0.4
	await _at(17.0)
	g.request_hint()
	await _at(19.5)

	_caption(4)
	_load(g, [[2, 2, 4, 8], [0, 4, 16, 32], [0, 0, 2, 64], [0, 0, 0, 2]], 1180)
	_push_in(3.5)
	await _at(20.2)
	g.request_move(Board.Dir.LEFT)
	await _at(20.9)
	g.request_move(Board.Dir.UP)
	await _at(21.7)
	g.undo()
	await _at(22.4)
	g.undo()
	await _at(23.0)

	_caption(5)
	_push_in(3.5)
	await _at(23.4)
	app.set_theme_mode(SaveStore.ThemeMode.LIGHT)
	_skin(App.THEME_FADE)
	await _at(24.6)
	g.start_new(6, false)
	_load(g, [[2, 4, 8, 16, 32, 64], [128, 256, 512, 1024, 2048, 4], [0, 2, 4, 8, 2, 0], [0, 0, 2, 0, 0, 0],
			[0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 2]], 41368)
	await _at(26.5)

	_end_card()
	await _at(LENGTH)


func _caption(i: int) -> void:
	var lines: Array = CAPTIONS[lang][i]
	for l: Label in [_title, _subtitle]:
		var tw := l.create_tween()
		tw.tween_property(l, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func() -> void: l.text = lines[0] if l == _title else lines[1])
		tw.tween_property(l, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Slow push-in on the phone screen for one scene.
func _push_in(duration: float) -> void:
	_screen.scale = Vector2.ONE
	_shadow.scale = Vector2.ONE
	var tw := _screen.create_tween()
	tw.tween_property(_screen, "scale", Vector2.ONE * 1.035, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _end_card() -> void:
	var p := Palette.current
	var tile := 168.0
	var gap := Design.SPACE_LG
	var x := (SIZE.x - tile * 4 - gap * 3) * 0.5
	for i in 4:
		var b := TileBadge.make(MenuScreen.LOGO_VALUES[i], tile, "2048"[i])
		b.text_ratio = 0.6
		b.position = Vector2(x + i * (tile + gap), 640)
		b.size = Vector2(tile, tile)
		b.scale = Vector2.ZERO
		_end.add_child(b)
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.5).set_delay(0.15 + i * 0.1) 				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var lines := [["2048 Merge", 96, Design.WEIGHT_HEAVY, p.text, 900.0],
			[CAPTIONS[lang][0][1], 44, Design.WEIGHT_MEDIUM, p.text_secondary, 1030.0],
			[END_LINE[lang], 36, Design.WEIGHT_BOLD, p.accent, 1130.0]]
	for line in lines:
		var l := Label.new()
		l.text = line[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(SIZE.x, 0)
		l.position.y = line[4]
		l.add_theme_font_override("font", Fonts.sans(line[2]))
		l.add_theme_font_size_override("font_size", line[1])
		l.add_theme_color_override("font_color", line[3])
		_end.add_child(l)
	var tw := _end.create_tween()
	tw.set_parallel()
	tw.tween_property(_end, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for n: CanvasItem in [_screen, _shadow, _title, _subtitle]:
		tw.tween_property(n, "modulate:a", 0.0, 0.5)


func _load(g: GameScreen, rows: Array, score: int) -> void:
	var flat := []
	for r in rows:
		flat.append_array(r)
	g.board.from_dict({"size": rows.size(), "values": flat, "score": score, "moves": 300})
	g._pending_over = false
	g._board_view.show_board(g.board, BoardView.Appear.FADE)
	g._board_view.hide_hint(true)
	g._refresh_scores(false)


static func _best_dir(board: Board, order: Array) -> Board.Dir:
	var best: Board.Dir = order[0]
	var best_gain := -1
	for d: Board.Dir in order:
		var probe := Board.new(board.size)
		probe.from_dict(board.to_dict())
		var r := probe.move(d)
		if r.moved and r.gained > best_gain:
			best_gain = r.gained
			best = d
	return best


func _tween(node: Node, prop: String, to: float, duration: float) -> void:
	node.create_tween().tween_property(node, prop, to, duration).set_trans(Tween.TRANS_SINE)


## Waits until [param t] seconds into the video.
func _at(t: float) -> void:
	while _frame < int(t * FPS):
		await process_frame
