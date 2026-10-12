class_name SaveStore
extends RefCounted
## Best scores, statistics, settings and the unfinished game, in one JSON file.
## Written to a temp file and renamed over the save, so a kill mid-write keeps the old one; the
## previous save is kept as a backup, and a file that cannot be read is set aside, never erased.

const DEFAULT_PATH := "user://save.json"
## Marks a file as this game's progress, so an import never takes some other JSON for it.
const APP_ID := "com.mahiron.merge2048"
const FORMAT_VERSION := 4
## Volume steps were 1..5 before format 3; they now span 1..Sfx.LEVEL_COUNT.
const LEGACY_VOLUME_STEPS := 5

enum ThemeMode { SYSTEM, LIGHT, DARK }
## Render resolution: short side 720, 1080 or 1440 pixels, never above the screen's own.
enum Quality { LOW, MEDIUM, HIGH }
## Strength of the move hint, see [HintLevels].
enum HintLevel { SIMPLE, MEDIUM, SMART }
## Text size: follow the phone's font scale, or a fixed step.
enum TextSize { SYSTEM, NORMAL, LARGE, XLARGE }
## Decorative motion: follow the phone's "remove animations", or force it on or off.
enum ReduceMotion { SYSTEM, ON, OFF }
## How [method load_from_disk] went.
enum Load {
	## No save yet: first launch.
	FRESH,
	## The save was read.
	OK,
	## The save could not be read and was set aside; the backup was loaded instead.
	RECOVERED,
	## Neither the save nor its backup could be read; both were set aside, defaults apply.
	LOST,
}

const THEME_NAMES := ["system", "light", "dark"]
const QUALITY_NAMES := ["low", "medium", "high"]
const HINT_LEVEL_NAMES := ["simple", "medium", "smart"]
const TEXT_SIZE_NAMES := ["system", "normal", "large", "xlarge"]
const REDUCE_MOTION_NAMES := ["system", "on", "off"]

var sound_on := true
var music_on := true
var haptics_on := true
## Shows the move hint button on the game screen.
var hints_on := true
var hint_level: HintLevel = HintLevel.MEDIUM
## Volume steps, 1 (quietest) to Sfx.LEVEL_COUNT.
var sound_volume := 7
var music_volume := 6
var show_fps := false
## Frame cap in frames per second, one of [constant DisplayRate.LIMITS]; 0 means no cap.
var fps_limit := 0
var theme: ThemeMode = ThemeMode.SYSTEM
var quality: Quality = Quality.HIGH
var text_size: TextSize = TextSize.SYSTEM
var reduce_motion: ReduceMotion = ReduceMotion.SYSTEM
## Two-letter UI language code, one of [constant I18n.LANGUAGES].
var language := "en"
## Moves that can be undone in a row, 0..Board.MAX_UNDO.
var undo_limit := Board.DEFAULT_UNDO
## Board size picked for the next new game.
var board_size := Board.DEFAULT_SIZE
## Output of [method Board.to_dict] for the game in progress (or lost and not yet left); empty
## when there is none.
var game: Dictionary = {}
## True once a save (or its backup) has been read, i.e. this is not the first launch.
var existed := false

## Best score per board size, keyed by side length.
var _best := {}
## Best score per board size of games played without undo or hints.
var _clean_best := {}
## Per board size: {games, score_sum, best_tile, moves, time, longest} (longest: most moves in one game).
var _stats := {}
var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


func backup_path() -> String:
	return _path + ".bak"


## Reads the save, falling back to its backup. A file that exists but cannot be read is renamed to
## "<name>.corrupt-<time>" so nothing is lost and it is never written over.
func load_from_disk() -> Load:
	var main: Variant = _read(_path)
	if main is Dictionary:
		_apply_loaded(main)
		return Load.OK
	var main_exists := FileAccess.file_exists(_path)
	if main_exists:
		_quarantine(_path)
	var backup: Variant = _read(backup_path())
	if backup is Dictionary:
		_apply_loaded(backup)
		# A missing save beside a good backup means a write was cut off between its two renames.
		return Load.RECOVERED if main_exists else Load.OK
	if FileAccess.file_exists(backup_path()):
		_quarantine(backup_path())
		return Load.LOST
	return Load.LOST if main_exists else Load.FRESH


## Persists the current state. Returns the first error encountered, or OK.
func save_to_disk() -> Error:
	return write_text(serialize())


## The save file contents for the current state; cheap enough for the main thread.
func serialize() -> String:
	return JSON.stringify(to_dict())


## Writes [param text] as the save file atomically, moving the previous save to the backup.
## Touches no state, so a worker thread may call it.
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
	if FileAccess.file_exists(_path):
		err = DirAccess.rename_absolute(_path, backup_path())
		if err != OK:
			return err
	return DirAccess.rename_absolute(tmp, _path)


func best_for(size: int) -> int:
	return _best.get(size, 0)


func clean_best_for(size: int) -> int:
	return _clean_best.get(size, 0)


## Records [param score] as the best for [param size] when it beats it. Returns true on a record.
func submit_score(score: int, size: int) -> bool:
	if score <= best_for(size):
		return false
	_best[size] = score
	return true


## Records [param score] of a game played without undo or hints, when it beats the best such game.
func submit_clean_score(score: int, size: int) -> bool:
	if score <= clean_best_for(size):
		return false
	_clean_best[size] = score
	return true


func has_game() -> bool:
	return not game.is_empty()


## Board size of the saved game, or 0 when there is none.
func game_size() -> int:
	if not has_game():
		return 0
	var n := Board.read_count(game.get("size"), Board.MAX_SIZE)
	return n if Board.is_valid_size(n) else 0


## Counts a move; an undo passes [param delta] = -1, so the total matches the moves that stand.
func record_move(size: int, delta := 1) -> void:
	var s := _stat(size)
	s.moves = maxi(0, s.moves + delta)


func record_best_tile(size: int, tile: int) -> void:
	var s := _stat(size)
	s.best_tile = maxi(s.best_tile, tile)


## Notes that a game on [param size] has reached [param moves] moves.
func record_longest(size: int, moves: int) -> void:
	var s := _stat(size)
	s.longest = maxi(s.longest, moves)


func add_play_time(size: int, seconds: float) -> void:
	_stat(size).time += maxf(seconds, 0.0)


## Counts a finished game (lost, or left for a new one after enough moves; the caller decides).
func record_game(size: int, score: int, best_tile: int) -> void:
	var s := _stat(size)
	s.games += 1
	s.score_sum += score
	s.best_tile = maxi(s.best_tile, best_tile)


## Clears games, average, best tile, moves and time for [param size], or for every size when 0.
func reset_stats(size: int) -> void:
	for n in _sizes(size):
		_stats.erase(n)


## Clears the best scores (with and without help) for [param size], or for every size when 0.
func reset_records(size: int) -> void:
	for n in _sizes(size):
		_best.erase(n)
		_clean_best.erase(n)


## Totals for one board size, or for all sizes when [param size] is 0.
## Keys: games, average_score, best_tile, best_score, clean_best_score, moves, time (seconds), and
## longest (most moves in one game).
func stats_for(size: int) -> Dictionary:
	var out := {"games": 0, "average_score": 0, "best_tile": 0, "best_score": 0, "clean_best_score": 0, "moves": 0, "time": 0.0,
			"longest": 0}
	var score_sum := 0
	for n in _sizes(size):
		var s: Dictionary = _stats.get(n, {})
		out.games += s.get("games", 0)
		score_sum += s.get("score_sum", 0)
		out.best_tile = maxi(out.best_tile, s.get("best_tile", 0))
		out.moves += s.get("moves", 0)
		out.longest = maxi(out.longest, s.get("longest", 0))
		out.time += s.get("time", 0.0)
		out.best_score = maxi(out.best_score, best_for(n))
		out.clean_best_score = maxi(out.clean_best_score, clean_best_for(n))
	if out.games > 0:
		out.average_score = roundi(float(score_sum) / out.games)
	return out


func to_dict() -> Dictionary:
	return {
		"app": APP_ID,
		"version": FORMAT_VERSION,
		"best_scores": _keyed(_best),
		"clean_best_scores": _keyed(_clean_best),
		"stats": _keyed(_stats),
		"settings": {
			"sound": sound_on,
			"music": music_on,
			"haptics": haptics_on,
			"hints": hints_on,
			"hint_level": HINT_LEVEL_NAMES[hint_level],
			"sound_volume": sound_volume,
			"music_volume": music_volume,
			"volume_steps": Sfx.LEVEL_COUNT,
			"show_fps": show_fps,
			"fps_limit": fps_limit,
			"theme": THEME_NAMES[theme],
			"quality": QUALITY_NAMES[quality],
			"text_size": TEXT_SIZE_NAMES[text_size],
			"reduce_motion": REDUCE_MOTION_NAMES[reduce_motion],
			"language": language,
			"undo_limit": undo_limit,
			"board_size": board_size,
		},
		"game": game,
	}


func apply_dict(d: Dictionary) -> void:
	var best = d.get("best_scores")
	if best is Dictionary:
		_read_scores(best, _best)
	else:
		# Saves before 1.2.0 had a single best score, always for the 4x4 board.
		var legacy := Board.read_count(d.get("best_score"), Board.MAX_SCORE)
		if legacy > 0:
			_best[Board.DEFAULT_SIZE] = legacy
	var clean = d.get("clean_best_scores")
	if clean is Dictionary:
		_read_scores(clean, _clean_best)
	var stats = d.get("stats")
	if stats is Dictionary:
		for key in stats:
			var n := _size_key(key)
			if n > 0 and stats[key] is Dictionary:
				var src: Dictionary = stats[key]
				var s := _stat(n)
				for field in ["games", "score_sum", "best_tile", "moves", "longest"]:
					var v := Board.read_count(src.get(field), Board.MAX_SCORE)
					if v >= 0:
						s[field] = v
				var t = src.get("time")
				# A century of play is more than any real save holds.
				if (t is int or t is float) and is_finite(t) and t >= 0 and t < 3.2e9:
					s.time = float(t)
	var s = d.get("settings", {})
	if s is Dictionary:
		sound_on = _bool_or(s.get("sound"), sound_on)
		music_on = _bool_or(s.get("music"), music_on)
		haptics_on = _bool_or(s.get("haptics"), haptics_on)
		hints_on = _bool_or(s.get("hints"), hints_on)
		var steps := LEGACY_VOLUME_STEPS if s.get("volume_steps") == null else Sfx.LEVEL_COUNT
		sound_volume = _volume_step(s.get("sound_volume"), steps, sound_volume)
		music_volume = _volume_step(s.get("music_volume"), steps, music_volume)
		undo_limit = _int_in(s.get("undo_limit"), 0, Board.MAX_UNDO, undo_limit)
		board_size = _int_in(s.get("board_size"), Board.MIN_SIZE, Board.MAX_SIZE, board_size)
		show_fps = _bool_or(s.get("show_fps"), show_fps)
		var limit = s.get("fps_limit")
		if (limit is int or limit is float) and (limit == 0 or DisplayRate.LIMITS.has(int(limit))) and int(limit) == limit:
			fps_limit = int(limit)
		theme = _name_or(s.get("theme"), THEME_NAMES, theme) as ThemeMode
		quality = _name_or(s.get("quality"), QUALITY_NAMES, quality) as Quality
		hint_level = _name_or(s.get("hint_level"), HINT_LEVEL_NAMES, hint_level) as HintLevel
		text_size = _name_or(s.get("text_size"), TEXT_SIZE_NAMES, text_size) as TextSize
		reduce_motion = _name_or(s.get("reduce_motion"), REDUCE_MOTION_NAMES, reduce_motion) as ReduceMotion
		var lang = s.get("language")
		if lang is String and I18n.LANGUAGES.has(lang):
			language = lang
	var g = d.get("game", {})
	game = g if g is Dictionary else {}


## The progress held in an exported file's [param text], or an empty dictionary when it is not
## this game's progress or comes from a newer version that this one cannot read.
static func parse_export(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary or parsed.get("app") != APP_ID:
		return {}
	var version := Board.read_count(parsed.get("version"), 1 << 16)
	if version < 1 or version > FORMAT_VERSION:
		return {}
	return parsed


func _apply_loaded(d: Dictionary) -> void:
	apply_dict(d)
	existed = true


## Parsed JSON of [param path], or null when it is missing or not a JSON object.
static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else null


static func _quarantine(path: String) -> void:
	var aside := "%s.corrupt-%d" % [path, int(Time.get_unix_time_from_system())]
	push_warning("Save file is unreadable, kept as %s" % aside)
	DirAccess.rename_absolute(path, aside)


func _stat(size: int) -> Dictionary:
	if not _stats.has(size):
		_stats[size] = {"games": 0, "score_sum": 0, "best_tile": 0, "moves": 0, "time": 0.0, "longest": 0}
	return _stats[size]


static func _sizes(size: int) -> Array:
	return [size] if size > 0 else range(Board.MIN_SIZE, Board.MAX_SIZE + 1)


static func _keyed(by_size: Dictionary) -> Dictionary:
	var out := {}
	for n in by_size:
		out[str(n)] = by_size[n]
	return out


static func _read_scores(src: Dictionary, into: Dictionary) -> void:
	for key in src:
		var n := _size_key(key)
		var v := Board.read_count(src[key], Board.MAX_SCORE)
		if n > 0 and v >= 0:
			into[n] = v


static func _size_key(key: Variant) -> int:
	var n := int(key) if (key is String and key.is_valid_int()) or key is int else 0
	return n if Board.is_valid_size(n) else 0


## Maps a volume step saved on a [param steps]-step scale onto the current one, ends kept fixed.
static func _volume_step(value: Variant, steps: int, fallback: int) -> int:
	var v := _int_in(value, 1, steps, -1)
	if v < 0:
		return fallback
	if steps == Sfx.LEVEL_COUNT:
		return v
	return roundi(float(v - 1) * (Sfx.LEVEL_COUNT - 1) / (steps - 1)) + 1


static func _int_in(value: Variant, lo: int, hi: int, fallback: int) -> int:
	var v := Board.read_count(value, hi)
	return v if v >= lo else fallback


static func _name_or(value: Variant, names: Array, fallback: int) -> int:
	var i := names.find(value) if value is String else -1
	return i if i >= 0 else fallback


static func _bool_or(value: Variant, fallback: bool) -> bool:
	return value if value is bool else fallback
