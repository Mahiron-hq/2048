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
		"test_milestones_fire_once",
		"test_serialization_round_trip",
		"test_rejects_malformed_state",
		"test_store_survives_restart",
		"test_store_ignores_corrupt_file",
		"test_store_best_score_only_increases",
		"test_music_loop_stays_in_bounds",
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
	check(b.undo(), "undo succeeds")
	check(b.values == before and b.score == 0 and b.move_count == 0, "state restored")
	check(not b.undo(), "only one undo step")


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
	var b := Board.new(2)
	b.new_game()
	b.move(Board.Dir.LEFT)
	b.move(Board.Dir.UP)
	s.game = b.to_dict()
	check(s.save_to_disk() == OK, "save ok")
	var t := SaveStore.new(path)
	check(t.load_from_disk() and t.existed, "load ok")
	check(t.best_score == 12345 and t.music_on and t.theme == SaveStore.ThemeMode.LIGHT and t.language == "ru", "settings restored")
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


func test_music_loop_stays_in_bounds() -> void:
	var wav := Sfx.build_music_stream()
	var frames := wav.data.size() / 2
	check(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music loops")
	# The mixer reads loop_end inclusively; it must index an existing frame.
	check(wav.loop_end >= 0 and wav.loop_end < frames, "loop_end %d within %d frames" % [wav.loop_end, frames])
	check(wav.data.decode_s16(wav.loop_end * 2) == wav.data.decode_s16(wav.loop_begin * 2), "seam frame repeats the loop start")
