class_name Palette
extends RefCounted
## Semantic color roles. Both themes fill the same roles; screens never pick raw colors.
##
## Tiles climb in three families: warm 2–64 (light sand to brick), golden 128–2048 (honey to
## copper) and deep 4096+ (wine through indigo to teal). Lightness falls within a family, so a
## bigger tile always reads heavier, and every family change marks a new milestone tier.

var dark: bool

## App background and its slightly deeper lower end.
var bg: Color
var bg_deep: Color
## Cards, list groups and the board's own surface.
var surface: Color
## Buttons, popovers and dialogs that sit above surfaces.
var surface_raised: Color
## The board under the tiles and the empty cells in it.
var board: Color
var cell: Color
## Tracks of switches, sliders and selectors.
var track: Color
## Hairlines: dividers and the edges of surfaces.
var outline: Color

var text: Color
var text_secondary: Color
## Disabled labels and inactive marks.
var text_tertiary: Color

## The one strong color: the main action, selection and the moments that matter.
var accent: Color
var accent_pressed: Color
var on_accent: Color
## Accent at a whisper, for selected rows and record badges.
var accent_soft: Color

## Modal backdrop.
var scrim: Color
var shadow: Color
## Fixed light ink used on dark overlays (swipe hint) in both themes.
var overlay_ink: Color

var _tile_bg: PackedColorArray
var _tile_dark_ink: int

const _INK_DARK := Color("3a2c22")
const _INK_LIGHT := Color("f8f3ec")

const _TILES_LIGHT := [
	"f6efe1", "f3e0c4", "f5c093", "f7a171", "ed835e", "ca5747",
	"eccf75", "ecba4f", "eba536", "e38b28", "da7224",
	"9e4048", "84395a", "663d70", "4a467d", "2d557d", "216573",
]
const _TILES_DARK := [
	"4e4640", "5e5147", "e4b48b", "e5976b", "dc7c5a", "bb5244",
	"dcc170", "dbae4f", "da9a38", "d3832c", "ca6b27",
	"923d43", "7a3653", "5f3967", "444173", "2b4f73", "215d6b",
]
## Bit i set: tile index i takes the dark ink (chosen for contrast; all pass 3:1 for large text).
const _DARK_INK_LIGHT := 0b00000011111011111
const _DARK_INK_DARK := 0b00000011111011100


static func make(is_dark: bool) -> Palette:
	var p := Palette.new()
	p.dark = is_dark
	if is_dark:
		p.bg = Color("1b1816")
		p.bg_deep = Color("161412")
		p.surface = Color("242120")
		p.surface_raised = Color("2e2a28")
		p.board = Color("262220")
		p.cell = Color("2f2a27")
		p.track = Color("3b3532")
		p.outline = Color("38322f")
		p.text = Color("f1ebe5")
		p.text_secondary = Color("aba096")
		p.text_tertiary = Color("70675f")
		p.accent = Color("e2794f")
		p.accent_pressed = Color("cf6a42")
		p.on_accent = Color("1d1410")
		p.accent_soft = Color(p.accent, 0.16)
		p.scrim = Color(0.04, 0.03, 0.03, 0.62)
		p.shadow = Color(0, 0, 0, 0.32)
		p._tile_dark_ink = _DARK_INK_DARK
	else:
		p.bg = Color("f5efe7")
		p.bg_deep = Color("efe7dc")
		p.surface = Color("fffcf8")
		p.surface_raised = Color("ffffff")
		p.board = Color("e3d9cc")
		p.cell = Color("d8ccbe")
		p.track = Color("e6ddd2")
		p.outline = Color("e4dace")
		p.text = Color("2c241e")
		p.text_secondary = Color("76685c")
		p.text_tertiary = Color("b2a598")
		p.accent = Color("be512d")
		p.accent_pressed = Color("a94625")
		p.on_accent = Color("ffffff")
		p.accent_soft = Color(p.accent, 0.11)
		p.scrim = Color(0.12, 0.08, 0.05, 0.42)
		p.shadow = Color(0.29, 0.18, 0.09, 0.10)
		p._tile_dark_ink = _DARK_INK_LIGHT
	p.overlay_ink = _INK_LIGHT
	p._tile_bg = PackedColorArray()
	for hex in (_TILES_DARK if is_dark else _TILES_LIGHT):
		p._tile_bg.append(Color(hex))
	return p


## Index into the tile ramp: 0 for the 2-tile, 1 for 4, and so on.
static func tile_index(value: int) -> int:
	var i := 0
	while value > 2:
		value >>= 1
		i += 1
	return i


func tile_bg(value: int) -> Color:
	return _tile_bg[mini(tile_index(value), _tile_bg.size() - 1)]


func tile_fg(value: int) -> Color:
	var i := mini(tile_index(value), _tile_bg.size() - 1)
	return _INK_DARK if _tile_dark_ink & (1 << i) else _INK_LIGHT


## From 128 up a tile is a milestone and gets a fine inner highlight.
func tile_is_milestone(value: int) -> bool:
	return value >= Board.FIRST_MILESTONE


## Palette in effect; UI nodes read it while drawing and are refreshed through
## [code]_on_skin_changed[/code] when it is replaced.
static var current: Palette = Palette.make(true)
