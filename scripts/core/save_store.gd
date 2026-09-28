class_name SaveStore
extends RefCounted
## Local persistence: best scores, statistics, settings and the unfinished game, in one JSON file.
##
## Writes go to a temporary file that is then renamed over the real one, so a process kill
## mid-write leaves the previous save intact instead of a truncated file.

const DEFAULT_PATH := "user://save.json"
const FORMAT_VERSION := 3
## Volume steps were 1..5 before format 3; they now span 1..Sfx.LEVEL_COUNT.
const LEGACY_VOLUME_STEPS := 5

enum ThemeMode { LIGHT, DARK }

var sound_on := true
var music_on := true
var haptics_on := true
## Volume steps, 1 (quietest) to Sfx.LEVEL_COUNT.
var sound_volume := 7
var music_volume := 6
var show_fps := false
var theme: ThemeMode = ThemeMode.DARK
## Two-letter UI language code, one of [constant I18n.LANGUAGES].
var language := "en"
## Moves that can be undone in a row, 0..Board.MAX_UNDO.
var undo_limit := Board.DEFAULT_UNDO
## Output of [method Board.to_dict] for the game in progress; empty when there is none.
var game: Dictionary = {}
## True once a valid save file has been read, i.e. this is not the first launch.
var existed := false

## Best score per board size, keyed by side length.
var _best := {}
## Per board size: {games, score_sum, best_tile, moves, time}.
var _stats := {}
var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


## Reads the save file. A missing file keeps defaults; a corrupt file keeps defaults for
## whatever could not be parsed. Returns false only when the file existed but was unreadable.
func load_from_disk() -> bool:
	if not FileAccess.file_exists(_path):
		return true
	var text := FileAccess.get_file_as_string(_path)
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("Save file is corrupt, using defaults: %s" % _path)
		return false
	apply_dict(parsed)
	existed = true
	return true


## Persists the current state. Returns the first error encountered, or OK.
func save_to_disk() -> Error:
	return write_text(serialize())


## The save file contents for the current state; cheap enough for the main thread.
func serialize() -> String:
	return JSON.stringify(to_dict())


## Writes [param text] as the save file atomically. Touches no store state, so it may run on a
## worker thread while the game keeps playing.
func write_text(text: String) -> Error:
	var tmp := _path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	var err := f.get_error()
	f.close()
	if err != OK:
		return err
	return DirAccess.rename_absolute(tmp, _path)


func best_for(size: int) -> int:
	return _best.get(size, 0)


## Records [param score] as the best for [param size] when it beats it. Returns true on a record.
func submit_score(score: int, size: int) -> bool:
	if score <= best_for(size):
		return false
	_best[size] = score
	return true


func has_game() -> bool:
	return not game.is_empty()


## Board size of the saved game, or 0 when there is none.
func game_size() -> int:
	if not has_game():
		return 0
	var n = game.get("size", 0)
	return int(n) if (n is int or n is float) else 0


## Counts a move; an undone move is taken back with [param delta] = -1, so the total matches
## the moves that actually stand.
func record_move(size: int, delta := 1) -> void:
	var s := _stat(size)
	s.moves = maxi(0, s.moves + delta)


func record_best_tile(size: int, tile: int) -> void:
	var s := _stat(size)
	s.best_tile = maxi(s.best_tile, tile)


func add_play_time(size: int, seconds: float) -> void:
	_stat(size).time += maxf(seconds, 0.0)


## Counts a finished game: lost, or abandoned for a new one after at least one move.
func record_game(size: int, score: int, best_tile: int) -> void:
	var s := _stat(size)
	s.games += 1
	s.score_sum += score
	s.best_tile = maxi(s.best_tile, best_tile)


## Totals for one board size, or for all sizes when [param size] is 0.
## Keys: games, average_score, best_tile, best_score, moves, time (seconds).
func stats_for(size: int) -> Dictionary:
	var sizes := [size] if size > 0 else range(Board.MIN_SIZE, Board.MAX_SIZE + 1)
	var out := {"games": 0, "average_score": 0, "best_tile": 0, "best_score": 0, "moves": 0, "time": 0.0}
	var score_sum := 0
	for n in sizes:
		var s: Dictionary = _stats.get(n, {})
		out.games += s.get("games", 0)
		score_sum += s.get("score_sum", 0)
		out.best_tile = maxi(out.best_tile, s.get("best_tile", 0))
		out.moves += s.get("moves", 0)
		out.time += s.get("time", 0.0)
		out.best_score = maxi(out.best_score, best_for(n))
	if out.games > 0:
		out.average_score = roundi(float(score_sum) / out.games)
	return out


func to_dict() -> Dictionary:
	var best := {}
	for n in _best:
		best[str(n)] = _best[n]
	var stats := {}
	for n in _stats:
		stats[str(n)] = _stats[n]
	return {
		"version": FORMAT_VERSION,
		"best_scores": best,
		"stats": stats,
		"settings": {
			"sound": sound_on,
			"music": music_on,
			"haptics": haptics_on,
			"sound_volume": sound_volume,
			"music_volume": music_volume,
			"volume_steps": Sfx.LEVEL_COUNT,
			"show_fps": show_fps,
			"theme": "light" if theme == ThemeMode.LIGHT else "dark",
			"language": language,
			"undo_limit": undo_limit,
		},
		"game": game,
	}


func apply_dict(d: Dictionary) -> void:
	var best = d.get("best_scores")
	if best is Dictionary:
		for key in best:
			var n := _size_key(key)
			if n > 0 and _is_count(best[key]):
				_best[n] = int(best[key])
	else:
		# Saves before 1.2.0 had a single best score, always for the 4x4 board.
		var legacy = d.get("best_score", 0)
		if _is_count(legacy) and legacy > 0:
			_best[Board.DEFAULT_SIZE] = int(legacy)
	var stats = d.get("stats")
	if stats is Dictionary:
		for key in stats:
			var n := _size_key(key)
			if n > 0 and stats[key] is Dictionary:
				var src: Dictionary = stats[key]
				var s := _stat(n)
				for field in ["games", "score_sum", "best_tile", "moves"]:
					if _is_count(src.get(field)):
						s[field] = int(src[field])
				var t = src.get("time")
				if (t is int or t is float) and t >= 0:
					s.time = float(t)
	var s = d.get("settings", {})
	if s is Dictionary:
		sound_on = _bool_or(s.get("sound"), sound_on)
		music_on = _bool_or(s.get("music"), music_on)
		haptics_on = _bool_or(s.get("haptics"), haptics_on)
		var steps := LEGACY_VOLUME_STEPS if s.get("volume_steps") == null else Sfx.LEVEL_COUNT
		sound_volume = _volume_step(s.get("sound_volume"), steps, sound_volume)
		music_volume = _volume_step(s.get("music_volume"), steps, music_volume)
		undo_limit = _int_in(s.get("undo_limit"), 0, Board.MAX_UNDO, undo_limit)
		show_fps = _bool_or(s.get("show_fps"), show_fps)
		match s.get("theme"):
			"light":
				theme = ThemeMode.LIGHT
			"dark":
				theme = ThemeMode.DARK
		var lang = s.get("language")
		if lang is String and I18n.LANGUAGES.has(lang):
			language = lang
	var g = d.get("game", {})
	game = g if g is Dictionary else {}


func _stat(size: int) -> Dictionary:
	if not _stats.has(size):
		_stats[size] = {"games": 0, "score_sum": 0, "best_tile": 0, "moves": 0, "time": 0.0}
	return _stats[size]


static func _size_key(key) -> int:
	var n := int(key) if (key is String and key.is_valid_int()) or key is int else 0
	return n if Board.is_valid_size(n) else 0


## Reads a volume step saved on a scale of [param steps] and maps it onto the current scale,
## keeping both ends (quietest and loudest) fixed.
static func _volume_step(value, steps: int, fallback: int) -> int:
	var v := _int_in(value, 1, steps, -1)
	if v < 0:
		return fallback
	if steps == Sfx.LEVEL_COUNT:
		return v
	return roundi(float(v - 1) * (Sfx.LEVEL_COUNT - 1) / (steps - 1)) + 1


static func _is_count(value) -> bool:
	return (value is int or value is float) and value >= 0 and int(value) == value


static func _int_in(value, lo: int, hi: int, fallback: int) -> int:
	if (value is int or value is float) and int(value) == value and value >= lo and value <= hi:
		return int(value)
	return fallback


static func _bool_or(value, fallback: bool) -> bool:
	return value if value is bool else fallback
