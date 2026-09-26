class_name Palette
extends RefCounted
## Colors for both themes. Tile colors are indexed by log2(value) - 1, so index 0 is the 2-tile.

var dark: bool
var bg_top: Color
var bg_bottom: Color
var board: Color
var cell: Color
var text: Color
var text_muted: Color
var accent: Color
var accent_text: Color
var surface: Color
var surface_pressed: Color
var surface_border: Color
var shadow: Color
var scrim: Color

var _tile_bg: PackedColorArray
var _tile_fg: PackedColorArray

const _WARM_BG := [
	"f9c28a", "f7a26a", "f4825e", "ee5f4e",
	"f5c04a", "efae35", "e89b24", "e0851b", "d86d17",
	"9c6ade", "7c4dd1", "5b3cc4", "3e3ab5", "2b5fb8", "1e8c9e",
]
const _WARM_FG := [
	"5e3b1e", "ffffff", "ffffff", "ffffff",
	"54370a", "4e3106", "ffffff", "ffffff", "ffffff",
	"ffffff", "ffffff", "ffffff", "ffffff", "ffffff", "ffffff",
]


static func make(is_dark: bool) -> Palette:
	var p := Palette.new()
	p.dark = is_dark
	if is_dark:
		p.bg_top = Color("1d1a29")
		p.bg_bottom = Color("121019")
		p.board = Color("262233")
		p.cell = Color("302b3f")
		p.text = Color("f3eef8")
		p.text_muted = Color("9d95b0")
		p.accent = Color("ff8a5c")
		p.accent_text = Color("1b1520")
		p.surface = Color("2b2639")
		p.surface_pressed = Color("363049")
		p.surface_border = Color("3a3450")
		p.shadow = Color(0, 0, 0, 0.35)
		p.scrim = Color(0.05, 0.04, 0.08, 0.72)
		p._tile_bg = PackedColorArray([Color("4a4257"), Color("5d4c5c")])
		p._tile_fg = PackedColorArray([Color("f1eaf7"), Color("fbeef0")])
	else:
		p.bg_top = Color("fdf9f4")
		p.bg_bottom = Color("f2eadf")
		p.board = Color("e3d7ca")
		p.cell = Color("efe6db")
		p.text = Color("3b3141")
		p.text_muted = Color("8d8093")
		p.accent = Color("f06a4a")
		p.accent_text = Color("ffffff")
		p.surface = Color("ffffff")
		p.surface_pressed = Color("f1e8de")
		p.surface_border = Color("e6dbcf")
		p.shadow = Color(0.35, 0.22, 0.12, 0.14)
		p.scrim = Color(0.98, 0.96, 0.93, 0.78)
		p._tile_bg = PackedColorArray([Color("f7ede2"), Color("f6dfc3")])
		p._tile_fg = PackedColorArray([Color("6b5a4e"), Color("6b5a4e")])
	for i in _WARM_BG.size():
		p._tile_bg.append(Color(_WARM_BG[i]))
		p._tile_fg.append(Color(_WARM_FG[i]))
	return p


static func tile_index(value: int) -> int:
	var i := 0
	while value > 2:
		value >>= 1
		i += 1
	return i


func tile_bg(value: int) -> Color:
	return _tile_bg[mini(tile_index(value), _tile_bg.size() - 1)]


func tile_fg(value: int) -> Color:
	return _tile_fg[mini(tile_index(value), _tile_fg.size() - 1)]


## Tiles from 128 up get a soft colored halo.
func tile_glows(value: int) -> bool:
	return value >= Board.FIRST_MILESTONE


## Palette in effect; UI nodes read it in their draw code and are refreshed through
## [code]_on_skin_changed[/code] when it is replaced.
static var current: Palette = Palette.make(true)
