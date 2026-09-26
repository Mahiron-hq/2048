class_name SaveStore
extends RefCounted
## Local persistence: best score, settings and the unfinished game, in one JSON file.
##
## Writes go to a temporary file that is then renamed over the real one, so a process kill
## mid-write leaves the previous save intact instead of a truncated file.

const DEFAULT_PATH := "user://save.json"
const FORMAT_VERSION := 1

enum ThemeMode { LIGHT, DARK }

var best_score := 0
var sound_on := true
var music_on := true
var haptics_on := true
var show_fps := false
var theme: ThemeMode = ThemeMode.DARK
## Two-letter UI language code, one of [constant I18n.LANGUAGES].
var language := "en"
## Output of [method Board.to_dict] for the game in progress; empty when there is none.
var game: Dictionary = {}
## True once a valid save file has been read, i.e. this is not the first launch.
var existed := false

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
	var tmp := _path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict()))
	var err := f.get_error()
	f.close()
	if err != OK:
		return err
	return DirAccess.rename_absolute(tmp, _path)


## Records [param score] as the best score when it beats it. Returns true on a new record.
func submit_score(score: int) -> bool:
	if score <= best_score:
		return false
	best_score = score
	return true


func has_game() -> bool:
	return not game.is_empty()


func to_dict() -> Dictionary:
	return {
		"version": FORMAT_VERSION,
		"best_score": best_score,
		"settings": {
			"sound": sound_on,
			"music": music_on,
			"haptics": haptics_on,
			"show_fps": show_fps,
			"theme": "light" if theme == ThemeMode.LIGHT else "dark",
			"language": language,
		},
		"game": game,
	}


func apply_dict(d: Dictionary) -> void:
	var best = d.get("best_score", 0)
	if (best is int or best is float) and best >= 0:
		best_score = int(best)
	var s = d.get("settings", {})
	if s is Dictionary:
		sound_on = _bool_or(s.get("sound"), sound_on)
		music_on = _bool_or(s.get("music"), music_on)
		haptics_on = _bool_or(s.get("haptics"), haptics_on)
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


static func _bool_or(value, fallback: bool) -> bool:
	return value if value is bool else fallback
