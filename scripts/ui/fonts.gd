class_name Fonts
extends RefCounted
## The bundled Roboto variable font at fixed weights, cached.
##
## System fonts are not used: some Android skins (e.g. Infinix XOS) resolve bold "sans-serif" to
## a serif face. System fonts stay as fallbacks for glyphs Roboto lacks.

const FONT_PATH := "res://assets/fonts/Roboto.ttf"
const FALLBACK_FAMILIES := ["Roboto", "Google Sans", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"]

const REGULAR := 400
const MEDIUM := 500
const SEMIBOLD := 600
const BOLD := 700
const BLACK := 900

## Replaces the bundled font in layout tests with a wider face (e.g. DejaVu Sans) to prove the
## layouts tolerate it. Null in the game.
static var override_font: Font = null
static var _cache := {}
static var _file: FontFile


## Returns the sans font at [param weight]. With [param tabular], digits share one width so
## counters do not jitter while they change.
static func sans(weight: int, tabular := false) -> Font:
	var key := weight * 2 + int(tabular)
	if _cache.has(key):
		return _cache[key]
	var ts := TextServerManager.get_primary_interface()
	var font := FontVariation.new()
	if override_font:
		font.base_font = override_font
		font.variation_embolden = (weight - REGULAR) / 500.0
	else:
		font.base_font = _roboto()
		font.variation_opentype = {ts.name_to_tag("wght"): weight}
	if tabular:
		font.opentype_features = {ts.name_to_tag("tnum"): 1}
	_cache[key] = font
	return font


static func _roboto() -> FontFile:
	if _file == null:
		_file = load(FONT_PATH)
		_file.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_file.hinting = TextServer.HINTING_LIGHT
		_file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		var system := SystemFont.new()
		system.font_names = PackedStringArray(FALLBACK_FAMILIES)
		system.fallbacks = [ThemeDB.fallback_font]
		_file.fallbacks = [system]
	return _file


static func clear_cache() -> void:
	_cache.clear()
	_file = null
