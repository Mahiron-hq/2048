class_name Fonts
extends RefCounted
## The bundled Manrope variable font at fixed weights, cached.
##
## Shipped with the game rather than taken from the system: some Android skins (e.g. Infinix
## XOS) map bold "sans-serif" to a serif face. System fonts only fill in glyphs Manrope lacks.

const FONT_PATH := "res://assets/fonts/Manrope.ttf"
const FALLBACK_FAMILIES := ["Roboto", "Google Sans", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"]
## Capital height of Manrope as a share of the font size; centers numerals optically.
const CAP_HEIGHT := 0.72

## Replaces the bundled font in layout tests with a wider face (e.g. DejaVu Sans) to prove the
## layouts tolerate it. Null in the game.
static var override_font: Font = null
static var _cache := {}
static var _file: FontFile


## Manrope at [param weight] (one of the Design.WEIGHT_* values). With [param tabular], digits
## share one width so counters do not jitter while they change; [param tracking] adds space
## between letters.
static func sans(weight: int, tabular := false, tracking := 0) -> Font:
	var key := (weight * 2 + int(tabular)) * 16 + tracking
	if _cache.has(key):
		return _cache[key]
	var ts := TextServerManager.get_primary_interface()
	var font := FontVariation.new()
	if override_font:
		font.base_font = override_font
		font.variation_embolden = (weight - Design.WEIGHT_REGULAR) / 400.0
	else:
		font.base_font = _manrope()
		font.variation_opentype = {ts.name_to_tag("wght"): weight}
	if tabular:
		font.opentype_features = {ts.name_to_tag("tnum"): 1}
	font.spacing_glyph = tracking
	_cache[key] = font
	return font


static func _manrope() -> FontFile:
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


## Baseline that puts capitals and digits of size [param font_size] centered on [param center_y].
static func baseline(center_y: float, font_size: int) -> float:
	return center_y + CAP_HEIGHT * font_size * 0.5


## Draws [param text] centered on [param center].
static func draw_centered(ci: CanvasItem, font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	ci.draw_string(font, Vector2(center.x - w * 0.5, baseline(center.y, font_size)), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Largest size up to [param font_size] at which [param text] fits [param width].
static func fit(font: Font, text: String, font_size: int, width: float, smallest := 10) -> int:
	var fs := font_size
	while fs > smallest and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		fs -= 1
	return fs


static func clear_cache() -> void:
	_cache.clear()
	_file = null
