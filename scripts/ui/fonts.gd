class_name Fonts
extends RefCounted
## Platform system fonts (Roboto on Android) at fixed weights, cached. Adds nothing to the APK.

const FAMILIES := ["Roboto", "Google Sans", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"]

const REGULAR := 400
const MEDIUM := 500
const SEMIBOLD := 600
const BOLD := 700
const BLACK := 900

static var _cache := {}


## Returns the system sans font at [param weight]. With [param tabular], digits share one width
## so counters do not jitter while they change.
static func sans(weight: int, tabular := false) -> Font:
	var key := weight * 2 + int(tabular)
	if _cache.has(key):
		return _cache[key]
	var base := SystemFont.new()
	base.font_names = PackedStringArray(FAMILIES)
	base.font_weight = weight
	base.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	base.hinting = TextServer.HINTING_LIGHT
	base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	base.fallbacks = [ThemeDB.fallback_font]
	var font: Font = base
	if tabular:
		var variation := FontVariation.new()
		variation.base_font = base
		var ts := TextServerManager.get_primary_interface()
		variation.opentype_features = {ts.name_to_tag("tnum"): 1}
		font = variation
	_cache[key] = font
	return font


static func clear_cache() -> void:
	_cache.clear()
