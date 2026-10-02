class_name TileArt
extends RefCounted
## How a tile looks, shared by the board, the logo and the badges: a rounded face over a thin
## darker edge, the number centered, and a fine top highlight from the first milestone up.

## Number size as a share of the tile side, by digit count (index 1 = one digit).
const DIGIT_RATIOS := [0.5, 0.5, 0.46, 0.38, 0.31, 0.26, 0.22]
## Widest the number may get, as a share of the tile side.
const TEXT_ROOM := 0.8

static var _font: Font


static func font() -> Font:
	if _font == null:
		_font = Fonts.sans(Design.WEIGHT_HEAVY)
	return _font


## [face, edge] style boxes for a tile of [param value] and side [param side].
static func styles(value: int, side: float) -> Array:
	var p := Palette.current
	var bg := p.tile_bg(value)
	var radius := int(roundf(side * Design.TILE_RADIUS))
	var edge := StyleBoxFlat.new()
	edge.bg_color = bg.darkened(0.14 if not p.dark else 0.32)
	edge.set_corner_radius_all(radius)
	edge.corner_detail = 10
	edge.anti_aliasing = true
	var face := StyleBoxFlat.new()
	face.bg_color = bg
	face.set_corner_radius_all(radius)
	face.corner_detail = 10
	face.anti_aliasing = true
	if p.tile_is_milestone(value):
		face.border_color = bg.lightened(0.22)
		face.border_width_top = maxi(2, int(side * 0.02))
		face.border_blend = true
	return [face, edge]


## Number size that fits [param text] on a tile of [param side].
static func font_size(text: String, side: float) -> int:
	var ratio: float = DIGIT_RATIOS[mini(text.length(), DIGIT_RATIOS.size() - 1)]
	return Fonts.fit(font(), text, int(side * ratio), side * TEXT_ROOM, 8)


## Edge height for a tile of [param side].
static func depth(side: float) -> float:
	return maxf(2.0, roundf(side * Design.TILE_DEPTH))


## Draws the tile into [param rect]. [param box] is a cached [method styles] result and
## [param fs] a cached [method font_size]; [param text] replaces the number when not empty.
static func draw(ci: CanvasItem, rect: Rect2, value: int, box: Array, fs: int, text := "") -> void:
	var d := depth(rect.size.y)
	draw_face(ci, rect, box, d)
	var label := text if not text.is_empty() else str(value)
	var face_center := rect.position + Vector2(rect.size.x * 0.5, (rect.size.y - d) * 0.5)
	Fonts.draw_centered(ci, font(), label, face_center, fs, Palette.current.tile_fg(value))


static func draw_face(ci: CanvasItem, rect: Rect2, box: Array, d: float) -> void:
	ci.draw_style_box(box[1], rect)
	ci.draw_style_box(box[0], Rect2(rect.position, Vector2(rect.size.x, rect.size.y - d)))


static func clear_cache() -> void:
	_font = null
