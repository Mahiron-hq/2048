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
	for x in Board.SIZE:
		out.append(b.values[Board.index_of(x, y)])
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
		for i in Board.CELL_COUNT:
			flat.append([0, 0, 2, 4, 8][rng.randi_range(0, 4)])
		var mirrored := []
		for y in Board.SIZE:
			for x in Board.SIZE:
				mirrored.append(flat[y * Board.SIZE + (Board.SIZE - 1 - x)])
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
		for y in Board.SIZE:
			for x in Board.SIZE:
				if a.values[Board.index_of(x, y)] != b.values[Board.index_of(Board.SIZE - 1 - x, y)]:
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
		for i in Board.CELL_COUNT:
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
	check(r.milestones == PackedInt32Array([128]), "first 128 fires: %s" % [r.milestones])
	var r2 := b.move(Board.Dir.UP)
	check(r2.milestones == PackedInt32Array([256]), "256 fires once: %s" % [r2.milestones])
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
	s.best_score = 12345
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
	check(t.best_score == 12345 and t.music_on and t.theme == SaveStore.ThemeMode.LIGHT and t.language == "ru", "settings restored")
	check(t.sound_volume == 2 and t.music_volume == 5, "volume steps restored")
	var junk := SaveStore.new("user://unused.json")
	junk.apply_dict({"settings": {"sound_volume": 9, "music_volume": 2.5}})
	check(junk.sound_volume == 5 and junk.music_volume == 4, "out-of-range volume steps fall back to defaults")
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
	check(s.best_score == 0 and not s.has_game(), "defaults kept")
	DirAccess.remove_absolute(path)


func test_store_best_score_only_increases() -> void:
	var s := SaveStore.new("user://unused.json")
	check(s.submit_score(100), "first record")
	check(not s.submit_score(50), "lower is not a record")
	check(s.best_score == 100, "best kept")


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
