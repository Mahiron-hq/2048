extends SceneTree
## Headless test runner: godot --headless --path . --script res://tests/run_tests.gd
## Exits with the number of failed tests.

var _failed := 0
var _passed := 0
var _current := ""


func _initialize() -> void:
	var tests := [
		"test_slide_left_merges_pairs_once",
		"test_no_chain_merge",
		"test_gap_merge",
		"test_noop_move_changes_nothing",
		"test_directions_are_mirror_images",
		"test_random_moves_conserve_sum",
		"test_ids_follow_tiles",
		"test_game_over_detection",
		"test_undo_single_step",
		"test_undo_replays_the_move",
		"test_undo_replay_survives_save",
		"test_undo_of_legacy_save_rebuilds",
		"test_milestones_fire_once",
		"test_serialization_round_trip",
		"test_rejects_malformed_state",
		"test_store_survives_restart",
		"test_store_ignores_corrupt_file",
		"test_store_best_score_only_increases",
		"test_music_loop_is_seamless",
		"test_every_size_plays",
		"test_sizes_serialize",
		"test_undo_many_steps_to_game_start",
		"test_undo_limit_caps_and_trims",
		"test_undo_disabled",
		"test_undo_stack_survives_save",
		"test_store_migrates_single_best_score",
		"test_store_best_scores_per_size",
		"test_statistics",
		"test_haptic_pulses_are_perceptible",
		"test_formatting",
		"test_merge_haptics_scale_with_tile",
		"test_game_over_wave",
		"test_volume_scale_migrates",
		"test_undone_moves_leave_the_statistics",
		"test_store_writes_from_a_worker_thread",
		"test_tiles_grow_past_32_bits",
		"test_fps_limit_options_follow_the_panel",
		"test_fps_limit_persists",
		"test_hint_solver_basics",
		"test_hint_solver_respects_its_budget",
		"test_hint_solver_plays_well",
		"test_hints_setting_persists",
		"test_haptics_without_strength_control",
		"test_theme_and_quality_persist",
		"test_palette_roles_and_tiles",
	]
	for t in tests:
		_current = t
		call(t)
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(_failed)


func check(cond: bool, msg := "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL %s: %s" % [_current, msg])


func board_from(rows: Array) -> Board:
	var b := Board.new(1)
	var flat := []
	for r in rows:
		flat.append_array(r)
	check(b.from_dict({"size": 4, "values": flat, "score": 0, "moves": 0}), "fixture should load")
	return b


func row(b: Board, y: int) -> Array:
	var out := []
	for x in b.size:
		out.append(b.values[b.index_of(x, y)])
	return out


func test_slide_left_merges_pairs_once() -> void:
	var b := board_from([[2, 2, 2, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
	var r := b.move(Board.Dir.LEFT)
	check(r.moved, "should move")
	check(row(b, 0) == [4, 4, 0, 0], "row0 %s" % [row(b, 0)])
	check(r.gained == 8 and b.score == 8, "score %d" % b.score)
	check(r.merges.size() == 2, "two merges")


func test_no_chain_merge() -> void:
	var b := board_from([[2, 2, 4, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
	b.move(Board.Dir.LEFT)
	check(row(b, 0).slice(0, 2) == [4, 4], "merged 4 must not merge again: %s" % [row(b, 0)])


func test_gap_merge() -> void:
	var b := board_from([[4, 0, 4, 8], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
	b.move(Board.Dir.LEFT)
	check(row(b, 0).slice(0, 2) == [8, 8], "row0 %s" % [row(b, 0)])


func test_noop_move_changes_nothing() -> void:
	var b := board_from([[2, 4, 8, 16], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
	var before := b.values.duplicate()
	var r := b.move(Board.Dir.LEFT)
	check(not r.moved, "left should be a no-op")
	check(r.spawn.is_empty(), "no spawn on no-op")
	check(b.values == before and b.move_count == 0 and not b.can_undo(), "state untouched")


func test_directions_are_mirror_images() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for n in 200:
		var flat := []
		for i in 16:
			flat.append([0, 0, 2, 4, 8][rng.randi_range(0, 4)])
		var mirrored := []
		for y in 4:
			for x in 4:
				mirrored.append(flat[y * 4 + (3 - x)])
		var a := board_from([flat.slice(0, 4), flat.slice(4, 8), flat.slice(8, 12), flat.slice(12, 16)])
		var b := board_from([mirrored.slice(0, 4), mirrored.slice(4, 8), mirrored.slice(8, 12), mirrored.slice(12, 16)])
		var ra := a.move(Board.Dir.LEFT)
		var rb := b.move(Board.Dir.RIGHT)
		check(ra.moved == rb.moved and ra.gained == rb.gained, "mirror moved/gain mismatch")
		# Ignore the random spawn when comparing.
		if not ra.spawn.is_empty():
			a.values[ra.spawn[1]] = 0
		if not rb.spawn.is_empty():
			b.values[rb.spawn[1]] = 0
		for y in 4:
			for x in 4:
				if a.values[a.index_of(x, y)] != b.values[b.index_of(3 - x, y)]:
					check(false, "mirror mismatch case %d" % n)
					return
	check(true)


func test_random_moves_conserve_sum() -> void:
	var b := Board.new(7)
	b.new_game()
	var dirs := [Board.Dir.UP, Board.Dir.DOWN, Board.Dir.LEFT, Board.Dir.RIGHT]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var ok := true
	for n in 3000:
		if not b.can_move():
			b.new_game()
		var sum_before := 0
		for v in b.values:
			sum_before += v
		var score_before := b.score
		var r := b.move(dirs[rng.randi_range(0, 3)])
		var sum_after := 0
		for v in b.values:
			sum_after += v
		var spawned := r.spawn[2] if not r.spawn.is_empty() else 0
		if sum_after != sum_before + spawned or b.score != score_before + r.gained:
			ok = false
			break
		if r.moved and r.spawn.is_empty():
			ok = false
			break
	check(ok, "tile sum and score must be conserved across moves")


func test_ids_follow_tiles() -> void:
	var b := Board.new(3)
	b.new_game()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for n in 500:
		if not b.can_move():
			b.new_game()
		b.move(rng.randi_range(0, 3))
		var seen := {}
		for i in b.cell_count:
			var has_value := b.values[i] != 0
			var has_id := b.ids[i] != 0
			if has_value != has_id or (has_id and seen.has(b.ids[i])):
				check(false, "ids must be unique and match occupied cells")
				return
			seen[b.ids[i]] = true
	check(true)


func test_game_over_detection() -> void:
	var b := board_from([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 2]])
	check(not b.can_move(), "checkerboard is stuck")
	var c := board_from([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 4]])
	check(c.can_move(), "adjacent pair allows a move")


func test_undo_single_step() -> void:
	var b := board_from([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
	var before := b.values.duplicate()
	b.move(Board.Dir.LEFT)
	check(b.can_undo(), "undo available after move")
	check(b.undo() != null, "undo succeeds")
	check(b.values == before and b.score == 0 and b.move_count == 0, "state restored")
	check(b.undo() == null, "only one undo step")


func test_undo_replays_the_move() -> void:
	var b := Board.new(21)
	b.new_game()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for n in 400:
		if not b.can_move():
			b.new_game()
		var values_before := b.values.duplicate()
		var ids_before := b.ids.duplicate()
		var dir: int = rng.randi_range(0, 3)
		var r := b.move(dir)
		if not r.moved:
			continue
		var u := b.undo()
		if u == null or not u.moved or u.slides != r.slides or u.merges != r.merges or u.spawn != r.spawn:
			check(false, "undo must return the same move (step %d)" % n)
			return
		if b.values != values_before or b.ids != ids_before:
			check(false, "undo must restore values and tile ids (step %d)" % n)
			return
		b.move(dir)
	check(true)


func test_undo_replay_survives_save() -> void:
	var b := board_from([[2, 2, 4, 0], [0, 4, 0, 4], [0, 0, 0, 0], [8, 0, 8, 0]])
	var r := b.move(Board.Dir.LEFT)
	var c := Board.new(1)
	check(c.from_dict(JSON.parse_string(JSON.stringify(b.to_dict()))), "reloads")
	check(c.ids == b.ids, "tile ids persist")
	var u := c.undo()
	check(u != null and u.moved and u.slides == r.slides and u.merges == r.merges and u.spawn == r.spawn, "undo after reload replays the move")
	var fresh := c.move(Board.Dir.RIGHT)
	var used := {}
	for id in c.ids:
		if id != 0 and used.has(id):
			check(false, "ids stay unique after reload")
		used[id] = true
	check(fresh.moved, "board keeps playing after reload + undo")


func test_undo_of_legacy_save_rebuilds() -> void:
	var legacy := {
		"size": 4, "values": [4, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "score": 4, "moves": 1,
		"undo": {"size": 4, "values": [2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "score": 0, "moves": 0},
	}
	var b := Board.new(1)
	check(b.from_dict(legacy), "1.0.0 save loads")
	var u := b.undo()
	check(u != null and not u.moved, "undo works but asks for a rebuild")
	check(b.values[0] == 2 and b.values[1] == 2 and b.ids[0] != 0 and b.ids[0] != b.ids[1], "values restored with fresh ids")


func test_milestones_fire_once() -> void:
	var b := board_from([[64, 64, 0, 0], [64, 64, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
	var r := b.move(Board.Dir.LEFT)
	check(r.milestones == PackedInt64Array([128]), "first 128 fires: %s" % [r.milestones])
	var r2 := b.move(Board.Dir.UP)
	check(r2.milestones == PackedInt64Array([256]), "256 fires once: %s" % [r2.milestones])
	var r3 := b.move(Board.Dir.RIGHT)
	check(r3.milestones.is_empty(), "plain swipe fires nothing: %s" % [r3.milestones])


func test_serialization_round_trip() -> void:
	var b := Board.new(11)
	b.new_game()
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for n in 60:
		b.move(rng.randi_range(0, 3))
	var json := JSON.stringify(b.to_dict())
	var c := Board.new(1)
	check(c.from_dict(JSON.parse_string(json)), "round trip loads through JSON")
	check(c.values == b.values and c.score == b.score and c.move_count == b.move_count and c.best_tile == b.best_tile, "same state")
	check(c.can_undo() == b.can_undo(), "undo step preserved")


func test_rejects_malformed_state() -> void:
	var b := Board.new(1)
	b.new_game()
	var before := b.values.duplicate()
	var bad := [
		{"size": 5, "values": [], "score": 0, "moves": 0},
		{"size": 7, "values": [], "score": 0, "moves": 0},
		{"size": 2, "values": [2, 0, 0, 0], "score": 0, "moves": 0},
		{"size": 4, "values": [3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "score": 0, "moves": 0},
		{"size": 4, "values": [2, 0, 0], "score": 0, "moves": 0},
		{"size": 4, "values": ["x", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "score": 0, "moves": 0},
		{"size": 4, "values": [2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "score": -5, "moves": 0},
	]
	for d in bad:
		check(not b.from_dict(d), "rejects %s" % [d])
	check(b.values == before, "board untouched after rejects")


func test_store_survives_restart() -> void:
	var path := "user://test_save.json"
	var s := SaveStore.new(path)
	s.submit_score(12345, 4)
	s.undo_limit = 3
	s.music_on = true
	s.theme = SaveStore.ThemeMode.LIGHT
	s.language = "ru"
	s.sound_volume = 2
	s.music_volume = 5
	var b := Board.new(2)
	b.new_game()
	b.move(Board.Dir.LEFT)
	b.move(Board.Dir.UP)
	s.game = b.to_dict()
	check(s.save_to_disk() == OK, "save ok")
	var t := SaveStore.new(path)
	check(t.load_from_disk() and t.existed, "load ok")
	check(t.best_for(4) == 12345 and t.undo_limit == 3 and t.music_on and t.theme == SaveStore.ThemeMode.LIGHT and t.language == "ru", "settings restored")
	check(t.sound_volume == 2 and t.music_volume == 5, "volume steps restored")
	var junk := SaveStore.new("user://unused.json")
	junk.apply_dict({"settings": {"sound_volume": 9, "music_volume": 2.5}})
	check(junk.sound_volume == 7 and junk.music_volume == 6, "out-of-range volume steps fall back to defaults")
	var c := Board.new(1)
	check(c.from_dict(t.game) and c.values == b.values, "game restored")
	check(c.can_undo() == b.can_undo(), "undo step restored")
	check(not FileAccess.file_exists(path + ".tmp"), "no temp file left")
	DirAccess.remove_absolute(path)


func test_store_ignores_corrupt_file() -> void:
	var path := "user://test_corrupt.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var s := SaveStore.new(path)
	check(not s.load_from_disk(), "reports corrupt file")
	check(s.best_for(4) == 0 and not s.has_game(), "defaults kept")
	DirAccess.remove_absolute(path)


func test_store_best_score_only_increases() -> void:
	var s := SaveStore.new("user://unused.json")
	check(s.submit_score(100, 4), "first record")
	check(not s.submit_score(50, 4), "lower is not a record")
	check(s.best_for(4) == 100, "best kept")


func test_music_loop_is_seamless() -> void:
	var looped := Sfx.make_music_stream()
	var linear := looped.duplicate() as AudioStreamMP3
	linear.loop = false
	linear.beat_count = 0
	var rate := Sfx.MUSIC_RATE
	var loop_end := Sfx.MUSIC_DELAY_FRAMES + Sfx.MUSIC_LOOP_FRAMES
	var span := 22050

	var seam := _render(looped, (loop_end - span + 0.5) / rate, span * 2)
	var tail := _render(linear, (loop_end - span + 0.5) / rate, span)
	var head := _render(linear, looped.loop_offset, span)
	# The frames before the wrap are the music's end, the frames after it the music's start.
	check(_max_abs_diff(seam, tail, 0, 0, span) < 1e-4, "loop plays the whole track up to the bar line")
	# Godot crossfades 256 frames of post-loop padding into the restart; compare after that.
	check(_max_abs_diff(seam, head, span + 256, 256, span - 256) < 1e-4, "loop restarts exactly at the first music frame")
	var jump := 0.0
	for i in range(span - 300, span + 300):
		jump = maxf(jump, absf(seam[i].x - seam[i - 1].x))
	check(jump < 0.01, "no click at the seam (max step %.4f)" % jump)

	# Anchor to the lossless master: frames 60000.. of the FLAC (mono) must line up with zero lag,
	# which pins MUSIC_DELAY_FRAMES to the exact frame.
	var ref := FileAccess.get_file_as_bytes("res://tests/data/master_frames_60000.f32").to_float32_array()
	var probe := _render(linear, (Sfx.MUSIC_DELAY_FRAMES + 60000 - 2 + 0.5) / rate, ref.size() + 4)
	var errs := PackedFloat32Array()
	for lag in 5:
		var e := 0.0
		for i in ref.size():
			var v := probe[lag + i]
			var d := (v.x + v.y) * 0.5 - ref[i]
			e += d * d
		errs.append(sqrt(e / ref.size()))
	check(errs[2] < 0.7 * minf(errs[1], errs[3]), "music starts at the measured encoder delay (errors by lag -2..2: %s)" % errs)


func _render(stream: AudioStream, from_sec: float, frames: int) -> PackedVector2Array:
	var pb := stream.instantiate_playback()
	pb.start(from_sec)
	var out := PackedVector2Array()
	while out.size() < frames:
		out.append_array(pb.mix_audio(1.0, mini(4096, frames - out.size())))
	return out


func _max_abs_diff(a: PackedVector2Array, b: PackedVector2Array, a0: int, b0: int, n: int) -> float:
	var m := 0.0
	for i in n:
		var d := a[a0 + i] - b[b0 + i]
		m = maxf(m, maxf(absf(d.x), absf(d.y)))
	return m


func test_every_size_plays() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for n in range(Board.MIN_SIZE, Board.MAX_SIZE + 1):
		var b := Board.new(n, n)
		b.new_game(n)
		check(b.size == n and b.values.size() == n * n and b.empty_count() == n * n - 2, "%dx%d opens with two tiles" % [n, n])
		var ok := true
		for step in 800:
			if not b.can_move():
				b.new_game()
			var before := 0
			for v in b.values:
				before += v
			var r := b.move(rng.randi_range(0, 3))
			var after := 0
			for v in b.values:
				after += v
			var spawned := r.spawn[2] if not r.spawn.is_empty() else 0
			if after != before + spawned:
				ok = false
				break
		check(ok, "%dx%d conserves tiles over random play" % [n, n])


func test_sizes_serialize() -> void:
	for n in range(Board.MIN_SIZE, Board.MAX_SIZE + 1):
		var b := Board.new(3, n)
		b.undo_limit = 5
		b.new_game(n)
		for step in 30:
			b.move(step % 4)
		var c := Board.new(1)
		c.undo_limit = 5
		check(c.from_dict(JSON.parse_string(JSON.stringify(b.to_dict()))), "%dx%d loads" % [n, n])
		check(c.size == n and c.values == b.values and c.score == b.score, "%dx%d round trip" % [n, n])
		check(c.undo_available() == b.undo_available(), "%dx%d undo history round trip" % [n, n])
	var small := Board.new(1, 3)
	small.new_game(3)
	var d := small.to_dict()
	d.size = 4
	check(not Board.new(1).from_dict(d), "cell count must match the size")


func test_undo_many_steps_to_game_start() -> void:
	var b := Board.new(5)
	b.undo_limit = 5
	b.new_game()
	var start := b.values.duplicate()
	var made := 0
	for dir in [Board.Dir.LEFT, Board.Dir.UP, Board.Dir.RIGHT, Board.Dir.DOWN, Board.Dir.LEFT, Board.Dir.UP]:
		if made == 3:
			break
		if b.move(dir).moved:
			made += 1
	check(b.undo_available() == 3, "only as many undos as moves made (%d)" % b.undo_available())
	for i in 3:
		var u := b.undo()
		check(u != null and u.moved, "undo step %d replays" % (i + 1))
	check(b.values == start and b.move_count == 0 and b.score == 0, "back at the start of the game")
	check(b.undo() == null and not b.can_undo(), "no undo past the start")
	check(b.move(Board.Dir.LEFT).moved or b.move(Board.Dir.RIGHT).moved, "game continues after undoing to the start")


func test_undo_limit_caps_and_trims() -> void:
	var b := Board.new(9)
	b.undo_limit = 3
	b.new_game()
	var moves := 0
	var guard := 0
	while moves < 6 and guard < 50:
		if b.move(guard % 4).moved:
			moves += 1
		guard += 1
	check(b.undo_available() == 3, "history capped at the limit")
	b.undo_limit = 2
	check(b.undo_available() == 2, "lowering the limit drops the oldest steps")
	check(b.undo() != null and b.undo() != null and b.undo() == null, "exactly two undos remain")
	b.undo_limit = 5
	check(b.undo_available() == 0, "raising the limit does not bring back dropped steps")


func test_undo_disabled() -> void:
	var b := Board.new(4)
	b.undo_limit = 0
	b.new_game()
	b.move(Board.Dir.LEFT)
	b.move(Board.Dir.UP)
	check(not b.can_undo() and b.undo() == null, "undo off records nothing")
	check(not b.to_dict().has("undo_stack"), "no history is saved")


func test_undo_stack_survives_save() -> void:
	var b := Board.new(12)
	b.undo_limit = 4
	b.new_game()
	var results: Array = []
	var guard := 0
	while results.size() < 4 and guard < 40:
		var r := b.move(guard % 4)
		if r.moved:
			results.append(r)
		guard += 1
	var c := Board.new(1)
	c.undo_limit = 4
	check(c.from_dict(JSON.parse_string(JSON.stringify(b.to_dict()))), "reloads with history")
	var ok := true
	for i in range(results.size() - 1, -1, -1):
		var u := c.undo()
		var r: Board.MoveResult = results[i]
		if u == null or not u.moved or u.slides != r.slides or u.merges != r.merges or u.spawn != r.spawn:
			ok = false
	check(ok, "every restored step replays the original move")


func test_store_migrates_single_best_score() -> void:
	var s := SaveStore.new("user://unused.json")
	s.apply_dict({"version": 1, "best_score": 20932, "settings": {}, "game": {}})
	check(s.best_for(4) == 20932 and s.best_for(5) == 0, "1.x best score becomes the 4x4 record")
	check(s.undo_limit == Board.DEFAULT_UNDO, "undo limit defaults to one step")


func test_store_best_scores_per_size() -> void:
	var s := SaveStore.new("user://unused.json")
	s.submit_score(500, 3)
	s.submit_score(900, 6)
	var t := SaveStore.new("user://unused.json")
	t.apply_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(t.best_for(3) == 500 and t.best_for(6) == 900 and t.best_for(4) == 0, "records are kept per size")
	t.apply_dict({"best_scores": {"9": 5, "x": 3, "5": -2}})
	check(t.best_for(5) == 0, "invalid entries are ignored")


func test_statistics() -> void:
	var s := SaveStore.new("user://unused.json")
	var empty := s.stats_for(0)
	check(empty.games == 0 and empty.average_score == 0 and empty.time == 0.0, "empty stats are zero")
	s.record_game(4, 1000, 128)
	s.record_game(4, 3000, 256)
	s.record_game(5, 500, 64)
	for i in 7:
		s.record_move(4)
	s.record_move(5)
	s.add_play_time(4, 90.5)
	s.add_play_time(5, 30.0)
	s.record_best_tile(5, 512)
	s.submit_score(3000, 4)
	var four := s.stats_for(4)
	check(four.games == 2 and four.average_score == 2000 and four.best_tile == 256 and four.moves == 7, "4x4 stats %s" % [four])
	check(four.best_score == 3000 and is_equal_approx(four.time, 90.5), "4x4 record and time")
	var all := s.stats_for(0)
	check(all.games == 3 and all.average_score == 1500 and all.best_tile == 512 and all.moves == 8, "overall stats %s" % [all])
	check(is_equal_approx(all.time, 120.5), "overall time")
	var t := SaveStore.new("user://unused.json")
	t.apply_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(t.stats_for(0) == all, "stats survive a save round trip")


func test_haptic_pulses_are_perceptible() -> void:
	check(Haptics.MIN_PULSE_MS >= 20, "minimum pulse long enough to feel")
	for kind in Haptics.Kind.values():
		check(Haptics.PULSE_MS[kind] >= Haptics.MIN_PULSE_MS, "pulse for kind %d is at least the minimum" % kind)
		check(Haptics.PREDEFINED.has(kind), "kind %d maps to a system effect" % kind)
	var ids := {}
	for kind in Haptics.PREDEFINED:
		ids[Haptics.PREDEFINED[kind]] = true
	check(ids.size() == Haptics.PREDEFINED.size(), "each kind uses a distinct system effect")


func test_merge_haptics_scale_with_tile() -> void:
	check(Haptics.merge_level(2) == 0, "merging 2s is silent")
	check(Haptics.merge_level(4) == 1, "merging 4s is the weakest buzz")
	check(Haptics.merge_level_count() == 15, "4 through 65536 is fifteen steps")
	var previous := 0
	var value := 4
	while value <= 65536:
		var level := Haptics.merge_level(value)
		check(level == previous + 1, "merging %d is one step stronger than the tile below (%d)" % [value, level])
		previous = level
		value *= 2
	check(Haptics.merge_level(131072) == Haptics.merge_level(65536) and Haptics.merge_level(1 << 20) == 15, "beyond 65536 stays at the strongest")
	var first := Haptics.merge_strength(1)
	var last := Haptics.merge_strength(Haptics.merge_level_count())
	check(first == 0.0 and last == 1.0, "strength spans the whole range")
	check(Haptics.merge_amplitude(first) == Haptics.MERGE_AMPLITUDE.x and Haptics.merge_amplitude(last) == 255, "amplitude spans the actuator range")
	var ratio_low := Haptics.merge_amplitude(Haptics.merge_strength(3)) / float(Haptics.merge_amplitude(Haptics.merge_strength(2)))
	var ratio_high := Haptics.merge_amplitude(Haptics.merge_strength(15)) / float(Haptics.merge_amplitude(Haptics.merge_strength(14)))
	check(absf(ratio_low - ratio_high) < 0.05, "each step feels equally stronger (%.3f vs %.3f)" % [ratio_low, ratio_high])
	check(Haptics.merge_ms(first) >= Haptics.MIN_PULSE_MS and Haptics.merge_ms(last) > Haptics.merge_ms(first) * 2, "pulse length also carries the strength")


func test_game_over_wave() -> void:
	var timings := Haptics.wave_timings()
	var amplitudes := Haptics.wave_amplitudes()
	check(timings.size() == amplitudes.size(), "one amplitude per waveform segment")
	var total := 0
	for ms in timings:
		total += ms
	check(total == 1000, "game-over wave lasts one second (%d ms)" % total)
	var swells: Array[int] = [0]
	var highest := 0
	var lowest := 255
	for i in amplitudes.size():
		if amplitudes[i] == 0:
			swells.append(0)
			continue
		swells[-1] += timings[i]
		highest = maxi(highest, amplitudes[i])
		lowest = mini(lowest, amplitudes[i])
	check(swells.size() == 2, "two swells with a pause between them: %s" % [swells])
	check(swells.size() == 2 and swells[1] * 2 == swells[0] * 3, "second swell is 1.5 times the first: %s" % [swells])
	check(highest <= 140 and lowest >= 40, "medium-soft: %d..%d of 255" % [lowest, highest])
	check(highest - lowest >= 40, "each swell rises and falls noticeably")

func test_formatting() -> void:
	var saved := I18n.current
	I18n.current = "en"
	check(I18n.number(1234567) == "1 234 567" and I18n.number(999) == "999", "thousands grouping: %s" % I18n.number(1234567))
	check(I18n.duration(45) == "45 s" and I18n.duration(125) == "2 min 5 s" and I18n.duration(3 * 3600 + 7 * 60) == "3 h 7 min", "durations")
	check(I18n.grid(5) == "5×5", "grid label")
	I18n.current = "ru"
	check(I18n.duration(3600) == "1 ч 0 мин", "russian duration")
	I18n.current = saved


func test_volume_scale_migrates() -> void:
	check(Sfx.LEVEL_COUNT == 7 and Sfx.LEVEL_DB.size() == 7, "seven volume steps")
	check(Sfx.level_db(Sfx.LEVEL_COUNT) == 0.0 and Sfx.level_db(1) < Sfx.level_db(2), "steps rise to 0 dB")
	var old := SaveStore.new("user://unused.json")
	old.apply_dict({"settings": {"sound_volume": 5, "music_volume": 4}})
	check(old.sound_volume == 7 and old.music_volume == 6, "1.2.0 steps map onto the 7-step scale (%d, %d)" % [old.sound_volume, old.music_volume])
	var lowest := SaveStore.new("user://unused.json")
	lowest.apply_dict({"settings": {"sound_volume": 1, "music_volume": 2}})
	check(lowest.sound_volume == 1 and lowest.music_volume == 3, "quietest stays quietest")
	var current := SaveStore.new("user://unused.json")
	current.apply_dict({"settings": {"sound_volume": 5, "music_volume": 4, "volume_steps": 7}})
	check(current.sound_volume == 5 and current.music_volume == 4, "current-scale values are kept")


func test_undone_moves_leave_the_statistics() -> void:
	var s := SaveStore.new("user://unused.json")
	s.record_move(4)
	s.record_move(4, -1)
	s.record_move(4)
	check(s.stats_for(4).moves == 1, "move, undo, move counts one move")
	s.record_move(4, -1)
	s.record_move(4, -1)
	check(s.stats_for(4).moves == 0, "never negative")


func test_store_writes_from_a_worker_thread() -> void:
	var path := "user://test_async_save.json"
	var s := SaveStore.new(path)
	s.submit_score(4242, 5)
	var text := s.serialize()
	var task := WorkerThreadPool.add_task(func() -> void: s.write_text(text))
	WorkerThreadPool.wait_for_task_completion(task)
	var t := SaveStore.new(path)
	check(t.load_from_disk() and t.best_for(5) == 4242, "a save written on a worker thread loads back")
	DirAccess.remove_absolute(path)


func test_tiles_grow_past_32_bits() -> void:
	var big := 1 << 30
	var b := Board.new(3)
	check(b.from_dict({"size": 4, "values": [big, big, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "score": 0, "moves": 0}), "board with 2^30 tiles loads")
	var r := b.move(Board.Dir.LEFT)
	check(r.moved and b.values[0] == 1 << 31, "two 2^30 tiles merge into 2^31, not a negative number: %d" % b.values[0])
	check(r.merges.size() == 1 and r.merges[0][3] == 1 << 31 and b.best_tile == 1 << 31, "merge result and best tile keep the full value")
	check(b.score == 1 << 31, "score counts the merged value")
	var c := Board.new(4)
	var text := JSON.stringify(b.to_dict())
	check(c.from_dict(JSON.parse_string(text)) and c.values == b.values, "2^31 tile survives a save and reload")
	var huge := Board.new(5)
	check(huge.from_dict({"size": 6, "values": [1 << 37] + range(35).map(func(_i: int) -> int: return 0), "score": 0, "moves": 0}), "a 2^37 tile (the 6x6 maximum) loads")


func test_fps_limit_options_follow_the_panel() -> void:
	check(DisplayRate.options_for(PackedFloat32Array([144.00002, 120.00001, 60.0])) == [30, 60, 120, 0], "60/120/144 Hz panel: no 90, which would stutter")
	check(DisplayRate.options_for(PackedFloat32Array([90.0, 60.0])) == [30, 60, 90, 0], "90 Hz panel")
	check(DisplayRate.options_for(PackedFloat32Array([120.0, 90.0, 60.0])) == [30, 60, 90, 120, 0], "panel with 90 and 120 Hz modes")
	check(DisplayRate.options_for(PackedFloat32Array([59.94])) == [30, 60, 0], "60 Hz panel keeps only 30 and 60")
	check(DisplayRate.options_for(PackedFloat32Array([165.0])) == [30, 60, 0], "165 Hz panel has no whole multiple of 90 or 120")
	check(DisplayRate.options_for(PackedFloat32Array([240.0])) == [30, 60, 120, 0], "240 Hz panel shows 120 evenly")
	check(DisplayRate.options_for(PackedFloat32Array()) == [30, 60, 0], "unknown panel: the always-safe caps")


func test_fps_limit_persists() -> void:
	var s := SaveStore.new("user://unused.json")
	check(s.fps_limit == 0, "no cap by default")
	s.fps_limit = 90
	var t := SaveStore.new("user://unused.json")
	t.apply_dict(JSON.parse_string(s.serialize()))
	check(t.fps_limit == 90, "cap survives a save and reload")
	for bad in [45, -30, 90.5, "60", true, 1000]:
		var u := SaveStore.new("user://unused.json")
		u.fps_limit = 60
		u.apply_dict({"settings": {"fps_limit": bad}})
		check(u.fps_limit == 60, "invalid cap %s is ignored" % [bad])


func test_hint_solver_basics() -> void:
	var solver := HintSolver.new()
	var only_left := board_from([[0, 2, 4, 8], [2, 4, 8, 16], [4, 8, 16, 32], [8, 16, 32, 64]])
	check(solver.best_move(only_left.values, 4, 50) in [Board.Dir.LEFT, Board.Dir.UP], "picks one of the moves that change the board")
	var stuck := board_from([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 2]])
	check(solver.best_move(stuck.values, 4, 50) == -1, "no hint when no move is possible")
	var one := board_from([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 0]])
	var forced := solver.best_move(one.values, 4, 50)
	check(forced == Board.Dir.RIGHT or forced == Board.Dir.DOWN, "the only moves that change the board are right and down (got %d)" % forced)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var illegal := 0
	for n in [3, 4, 5, 6]:
		for trial in 30:
			var b := Board.new(rng.randi_range(0, 1 << 30), n)
			b.new_game()
			for step in rng.randi_range(0, 40):
				if not b.can_move():
					break
				b.move(rng.randi_range(0, 3))
			if not b.can_move():
				continue
			var dir := solver.best_move(b.values, n, 3)
			var probe := Board.new(1, n)
			probe.from_dict(b.to_dict())
			if dir < 0 or not probe.move(dir).moved:
				illegal += 1
	check(illegal == 0, "every hint on random 3x3..6x6 boards is a legal move (%d illegal)" % illegal)


func test_hint_solver_respects_its_budget() -> void:
	var solver := HintSolver.new()
	var b := Board.new(11, 6)
	b.new_game()
	for i in 60:
		if b.can_move():
			b.move(i % 4)
	var t0 := Time.get_ticks_msec()
	solver.best_move(b.values, 6, 60)
	var took := Time.get_ticks_msec() - t0
	check(took < 400, "a 60 ms budget on a 6x6 board ends in time (%d ms, depth %d)" % [took, solver.last_depth])


func test_hint_solver_plays_well() -> void:
	# Following the hints with a tiny budget still gets far, so they are genuinely good moves.
	var solver := HintSolver.new()
	var b := Board.new(2026, 4)
	b.new_game()
	while b.can_move() and b.best_tile < 1024:
		b.move(solver.best_move(b.values, 4, 8))
	check(b.best_tile >= 1024, "following the hints reaches 1024 (best tile %d after %d moves)" % [b.best_tile, b.move_count])


func test_hints_setting_persists() -> void:
	var s := SaveStore.new("user://unused.json")
	check(s.hints_on, "move hints are on by default")
	s.hints_on = false
	var t := SaveStore.new("user://unused.json")
	t.apply_dict(JSON.parse_string(s.serialize()))
	check(not t.hints_on, "turning hints off survives a restart")


func test_haptics_without_strength_control() -> void:
	# Merges step through the maker's tuned effects from the lightest to the heaviest.
	var tiers: Array = []
	for level in range(1, Haptics.merge_level_count() + 1):
		var tier := Haptics.merge_tier(level)
		check(Haptics.MERGE_TIERS.has(tier), "level %d maps to a predefined effect" % level)
		if tiers.is_empty() or tiers[-1] != tier:
			tiers.append(tier)
	check(tiers == Haptics.MERGE_TIERS, "merges climb through every tier in order: %s" % [tiers])
	check(Haptics.merge_tier(1) == Haptics.MERGE_TIERS[0] and Haptics.merge_tier(Haptics.merge_level_count()) == Haptics.MERGE_TIERS[-1], "4s get the lightest, 65536 the heaviest")
	# The game-over wave becomes short spaced pulses with the same one-second two-swell shape.
	var timings := Haptics.pulse_wave_timings()
	check(timings[0] == 0 and timings.size() % 2 == 1, "pattern starts with a zero-length pause, then on/off pairs")
	var total := 0
	var longest := 0
	var swells: Array[int] = [0]
	for i in timings.size():
		total += timings[i]
		if i % 2 == 1:
			longest = maxi(longest, timings[i])
			check(timings[i] >= Haptics.WAVE_PULSE_MS.x and timings[i] <= Haptics.WAVE_PULSE_MS.y, "pulse %d is short (%d ms)" % [i, timings[i]])
		if i > 0 and i % 2 == 0 and timings[i] >= Haptics.WAVE_PAUSE_MS:
			swells.append(0)
		elif i > 0:
			swells[-1] += timings[i]
	check(total == 1000, "still one second in total (%d ms)" % total)
	check(swells.size() == 2, "two swells separated by the pause: %s" % [swells])
	check(longest <= Haptics.WAVE_PULSE_MS.y, "no long continuous buzz (longest pulse %d ms)" % longest)


func test_theme_and_quality_persist() -> void:
	var fresh := SaveStore.new("user://unused.json")
	check(fresh.theme == SaveStore.ThemeMode.SYSTEM and fresh.quality == SaveStore.Quality.HIGH, "new players follow the system theme at high quality")
	var path := "user://test_theme.json"
	var s := SaveStore.new(path)
	s.theme = SaveStore.ThemeMode.SYSTEM
	s.quality = SaveStore.Quality.LOW
	check(s.save_to_disk() == OK, "save ok")
	var t := SaveStore.new(path)
	t.theme = SaveStore.ThemeMode.DARK
	check(t.load_from_disk() and t.theme == SaveStore.ThemeMode.SYSTEM and t.quality == SaveStore.Quality.LOW, "system theme and low quality restored")
	DirAccess.remove_absolute(path)
	var legacy := SaveStore.new("user://unused.json")
	legacy.apply_dict({"settings": {"theme": "dark"}})
	check(legacy.theme == SaveStore.ThemeMode.DARK and legacy.quality == SaveStore.Quality.HIGH, "an older save keeps its chosen theme and gets high quality")
	var junk := SaveStore.new("user://unused.json")
	junk.apply_dict({"settings": {"theme": "sepia", "quality": 7}})
	check(junk.theme == SaveStore.ThemeMode.SYSTEM and junk.quality == SaveStore.Quality.HIGH, "unknown theme and quality values fall back to defaults")


## Every tile number stays readable: WCAG large-text contrast (3:1) on its tile, in both themes;
## and neighbouring values never share a color.
func test_palette_roles_and_tiles() -> void:
	for dark in [false, true]:
		var p := Palette.make(dark)
		var worst := 99.0
		var value := 2
		var previous := Color.TRANSPARENT
		var distinct := true
		for i in 17:
			worst = minf(worst, _contrast(p.tile_bg(value), p.tile_fg(value)))
			distinct = distinct and p.tile_bg(value) != previous
			previous = p.tile_bg(value)
			value *= 2
		check(worst >= 3.0, "tile numbers keep 3:1 contrast (%s theme, worst %.2f)" % ["dark" if dark else "light", worst])
		check(distinct, "neighbouring tiles differ in color")
		check(_contrast(p.text, p.bg) >= 7.0 and _contrast(p.text_secondary, p.surface) >= 4.5, "body and secondary text meet AA on their surfaces")
		check(_contrast(p.on_accent, p.accent) >= 4.5, "accent buttons keep 4.5:1 for their labels")
	check(Palette.make(false).tile_bg(1 << 40) == Palette.make(false).tile_bg(1 << 17), "tiles past the ramp keep its last color")


## WCAG contrast ratio, from the relative luminance of the linearized colors.
func _contrast(a: Color, b: Color) -> float:
	var la := _relative_luminance(a)
	var lb := _relative_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _relative_luminance(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b

