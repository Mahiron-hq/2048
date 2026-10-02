class_name Icons
extends RefCounted
## Line icons drawn with canvas primitives: one stroke weight, round ends and joins, so they stay
## sharp at any density and read as one set.

enum Kind { NONE, MENU, UNDO, RESTART, BACK, GEAR, PLAY, TROPHY, CHECK, SPEAKER_LOW, SPEAKER_HIGH, GRID, CHART, BULB }

## Stroke width as a share of the icon box.
const STROKE := 0.085
## Round end radius as a share of the stroke; antialiased lines render a touch thinner than
## their width, so a full half-width cap would bulge.
const CAP := 0.42


## Draws [param kind] centered on [param center], fitting a square of side [param s].
static func draw(ci: CanvasItem, kind: Kind, center: Vector2, s: float, color: Color) -> void:
	var w := maxf(2.0, s * STROKE)
	var c := center
	match kind:
		Kind.MENU:
			for k in [-1, 0, 1]:
				_line(ci, c + Vector2(-0.3, k * 0.22) * s, c + Vector2(0.3, k * 0.22) * s, color, w)
		Kind.UNDO:
			_circular_arrow(ci, c, s, w, color, false)
		Kind.RESTART:
			_circular_arrow(ci, c, s, w, color, true)
		Kind.BACK:
			_path(ci, [c + Vector2(0.1, -0.28) * s, c + Vector2(-0.16, 0) * s, c + Vector2(0.1, 0.28) * s], color, w)
		Kind.GEAR:
			var teeth := 8
			var pts: Array[Vector2] = []
			for i in teeth:
				var a := TAU * i / teeth
				pts.append(c + Vector2.from_angle(a - 0.36) * s * 0.29)
				pts.append(c + Vector2.from_angle(a - 0.17) * s * 0.4)
				pts.append(c + Vector2.from_angle(a + 0.17) * s * 0.4)
				pts.append(c + Vector2.from_angle(a + 0.36) * s * 0.29)
			pts.append(pts[0])
			_path(ci, pts, color, w)
			ci.draw_arc(c, s * 0.12, 0.0, TAU, 32, color, w, true)
		Kind.PLAY:
			_path(ci, [c + Vector2(-0.18, -0.28) * s, c + Vector2(0.28, 0) * s, c + Vector2(-0.18, 0.28) * s,
					c + Vector2(-0.18, -0.28) * s], color, w)
		Kind.TROPHY:
			var cup: Array[Vector2] = [c + Vector2(-0.22, -0.32) * s]
			for i in 13:
				var a := PI * i / 12.0
				cup.append(c + Vector2(-cos(a) * 0.22, -0.32 + sin(a) * 0.38) * s)
			cup.append(c + Vector2(0.22, -0.32) * s)
			cup.append(cup[0])
			_path(ci, cup, color, w)
			_arc(ci, c + Vector2(-0.24, -0.16) * s, s * 0.1, PI * 0.5, PI * 1.5, color, w)
			_arc(ci, c + Vector2(0.24, -0.16) * s, s * 0.1, -PI * 0.5, PI * 0.5, color, w)
			_line(ci, c + Vector2(0, 0.06) * s, c + Vector2(0, 0.26) * s, color, w)
			_line(ci, c + Vector2(-0.16, 0.3) * s, c + Vector2(0.16, 0.3) * s, color, w)
		Kind.SPEAKER_LOW, Kind.SPEAKER_HIGH:
			_path(ci, [c + Vector2(-0.36, -0.1) * s, c + Vector2(-0.22, -0.1) * s, c + Vector2(-0.04, -0.28) * s,
					c + Vector2(-0.04, 0.28) * s, c + Vector2(-0.22, 0.1) * s, c + Vector2(-0.36, 0.1) * s,
					c + Vector2(-0.36, -0.1) * s], color, w)
			var waves := [0.14] if kind == Kind.SPEAKER_LOW else [0.14, 0.3]
			for r in waves:
				_arc(ci, c + Vector2(0.02, 0) * s, s * r, -PI * 0.28, PI * 0.28, color, w)
		Kind.GRID:
			var cell := s * 0.24
			for gy in 2:
				for gx in 2:
					var o := c + Vector2((gx - 0.5) * 0.36, (gy - 0.5) * 0.36) * s - Vector2(cell, cell) * 0.5
					_rect(ci, Rect2(o, Vector2(cell, cell)), color, w)
		Kind.CHART:
			var base := c.y + s * 0.3
			for i in 3:
				var x := c.x + (i - 1) * s * 0.24
				_line(ci, Vector2(x, base), Vector2(x, base - s * (0.26 + 0.17 * i)), color, w * 1.2)
		Kind.BULB:
			var r := s * 0.24
			var glass := c + Vector2(0, -s * 0.1)
			var open := 0.62
			ci.draw_arc(glass, r, PI * 0.5 + open, PI * 2.5 - open, 36, color, w, true)
			var left := glass + Vector2.from_angle(PI * 0.5 + open) * r
			var right := glass + Vector2.from_angle(PI * 0.5 - open) * r
			var neck := c.y + s * 0.19
			_path(ci, [left, Vector2(left.x, neck), Vector2(right.x, neck), right], color, w)
			_line(ci, Vector2(left.x + w * 0.5, neck + s * 0.12), Vector2(right.x - w * 0.5, neck + s * 0.12), color, w)
		Kind.CHECK:
			_path(ci, [c + Vector2(-0.26, 0.0) * s, c + Vector2(-0.08, 0.18) * s, c + Vector2(0.28, -0.2) * s], color, w * 1.15)


static func _line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, w: float) -> void:
	ci.draw_line(a, b, color, w, true)
	ci.draw_circle(a, w * CAP, color, true, -1.0, true)
	ci.draw_circle(b, w * CAP, color, true, -1.0, true)


## Polyline with round joins and ends.
static func _path(ci: CanvasItem, pts: Array, color: Color, w: float) -> void:
	ci.draw_polyline(PackedVector2Array(pts), color, w, true)
	for p: Vector2 in pts:
		ci.draw_circle(p, w * CAP, color, true, -1.0, true)


static func _arc(ci: CanvasItem, center: Vector2, r: float, a0: float, a1: float, color: Color, w: float) -> void:
	ci.draw_arc(center, r, a0, a1, 24, color, w, true)
	ci.draw_circle(center + Vector2.from_angle(a0) * r, w * CAP, color, true, -1.0, true)
	ci.draw_circle(center + Vector2.from_angle(a1) * r, w * CAP, color, true, -1.0, true)


static func _rect(ci: CanvasItem, r: Rect2, color: Color, w: float) -> void:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = color
	box.set_border_width_all(int(roundf(w)))
	box.set_corner_radius_all(int(r.size.x * 0.22))
	box.corner_detail = 6
	box.anti_aliasing = true
	ci.draw_style_box(box, r.grow(w * 0.5))


## Open ring with a chevron head; clockwise for restart, counter-clockwise for undo.
static func _circular_arrow(ci: CanvasItem, center: Vector2, s: float, w: float, color: Color, clockwise: bool) -> void:
	var r := s * 0.28
	var gap := 1.0
	var a0 := -PI * 0.5 + gap * 0.5
	var a1 := a0 + TAU - gap
	_arc(ci, center, r, a0, a1, color, w)
	var head_angle := a1 if clockwise else a0
	var p := center + Vector2.from_angle(head_angle) * r
	var tangent := Vector2(-sin(head_angle), cos(head_angle)) * (1.0 if clockwise else -1.0)
	var normal := tangent.orthogonal()
	var head := s * 0.15
	_path(ci, [p - tangent * head + normal * head, p, p - tangent * head - normal * head], color, w)
