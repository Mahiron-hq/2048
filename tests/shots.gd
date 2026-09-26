extends SceneTree
## Windowed capture of every screen in both themes:
## godot --path . --script res://tests/shots.gd  (writes screenshots/shots/*.png)

const OUT := "res://screenshots/shots/"
const SAVE := "user://capture_save.json"

var app: App


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.remove_absolute(SAVE)
	app = load("res://scenes/main.tscn").instantiate()
	app.store = SaveStore.new(SAVE)
	root.add_child(app)
	_run.call_deferred()


func _run() -> void:
	for dark in [true, false]:
		var tag := "dark" if dark else "light"
		app.set_theme_mode(SaveStore.ThemeMode.DARK if dark else SaveStore.ThemeMode.LIGHT)
		app.set_language("ru")
		app._to_menu()
		await _wait(1.2)
		_shot("menu_" + tag)

		app._start_new_game()
		await _wait(0.8)
		_load_board([[2, 4, 8, 16], [32, 64, 128, 256], [512, 1024, 2048, 4096], [0, 2, 0, 8192]], 51234)
		await _wait(0.6)
		_shot("game_tiles_" + tag)

		_load_board([[64, 64, 4, 2], [8, 0, 0, 2], [0, 0, 0, 0], [0, 2, 0, 0]], 1320)
		await _wait(0.5)
		app._game.request_move(Board.Dir.LEFT)
		await _wait(0.45)
		_shot("game_milestone_" + tag)
		await _wait(2.4)

		app._game.start_new()
		await _wait(0.6)
		_shot("game_start_" + tag)
		app._game._ask_new_game()
		app._game.request_move(Board.Dir.LEFT)
		app._game.request_move(Board.Dir.UP)
		app._game._ask_new_game()
		await _wait(0.6)
		_shot("confirm_" + tag)
		app._confirm.close()
		await _wait(0.4)

		_load_board([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 16], [4, 2, 8, 8]], 2890)
		await _wait(0.4)
		app._game.request_move(Board.Dir.LEFT)
		await _wait(2.2)
		_shot("game_over_" + tag)
		app._game._game_over.close()
		await _wait(0.4)

		app._open_settings()
		await _wait(0.6)
		_shot("settings_" + tag)
		app._close_settings()
		await _wait(0.4)
	app.set_language("en")
	app._to_menu()
	await _wait(1.0)
	_shot("menu_en")
	quit(0)


func _load_board(rows: Array, score: int) -> void:
	var flat := []
	for r in rows:
		flat.append_array(r)
	var g := app._game
	g.board.from_dict({"size": 4, "values": flat, "score": score, "moves": 40})
	g._pending_over = false
	app.store.submit_score(score)
	g._board_view.show_board(g.board, BoardView.Appear.FADE)
	g._refresh_scores(false)


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("shot ", name)
