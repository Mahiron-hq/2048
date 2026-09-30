class_name Icons
extends RefCounted
## Vector UI glyphs drawn with canvas primitives, so they stay sharp at any density.

enum Kind { NONE, MENU, UNDO, RESTART, BACK, GEAR, PLAY, TROPHY, CHECK, SPEAKER_LOW, SPEAKER_HIGH, GRID, CHART, BULB }


## Draws [param kind] centered on [param center], fitting a square of side [param s].
static func draw(ci: CanvasItem, kind: Kind, center: Vector2, s: float, color: Color) -> void:
	var w := maxf(2.0, s * 0.11)
	var h := s * 0.5
	match kind:
		Kind.MENU:
			for k in [-1, 0, 1]:
				var y: float = center.y + k * s * 0.28
				ci.draw_line(Vector2(center.x - h * 0.85, y), Vector2(center.x + h * 0.85, y), color, w, true)
				ci.draw_circle(Vector2(center.x - h * 0.85, y), w * 0.5, color, true, -1.0, true)
				ci.draw_circle(Vector2(center.x + h * 0.85, y), w * 0.5, color, true, -1.0, true)
		Kind.UNDO:
			_circular_arrow(ci, center, s, w, color, false)
		Kind.RESTART:
			_circular_arrow(ci, center, s, w, color, true)
		Kind.BACK:
			var pts := PackedVector2Array([
				center + Vector2(s * 0.12, -s * 0.3),
				center + Vector2(-s * 0.18, 0),
				center + Vector2(s * 0.12, s * 0.3),
			])
			ci.draw_polyline(pts, color, w * 1.1, true)
			for p in [pts[0], pts[1], pts[2]]:
				ci.draw_circle(p, w * 0.55, color, true, -1.0, true)
		Kind.GEAR:
			ci.draw_arc(center, s * 0.22, 0.0, TAU, 32, color, w * 1.5, true)
			for i in 8:
				var d := Vector2.from_angle(TAU * i / 8.0)
				ci.draw_line(center + d * s * 0.28, center + d * s * 0.42, color, w * 1.7, true)
		Kind.PLAY:
			var pts := PackedVector2Array([
				center + Vector2(-s * 0.2, -s * 0.3),
				center + Vector2(s * 0.3, 0),
				center + Vector2(-s * 0.2, s * 0.3),
			])
			ci.draw_colored_polygon(pts, color)
			pts.append(pts[0])
			ci.draw_polyline(pts, color, w * 0.6, true)
		Kind.TROPHY:
			var cup := PackedVector2Array()
			var top := center.y - s * 0.34
			for i in 17:
				var a := PI * i / 16.0
				cup.append(Vector2(center.x + cos(a) * s * 0.26, top + sin(a) * s * 0.42))
			cup.append(Vector2(center.x - s * 0.26, top))
			ci.draw_colored_polygon(cup, color)
			ci.draw_arc(Vector2(center.x - s * 0.27, top + s * 0.14), s * 0.12, PI * 0.5, PI * 1.5, 12, color, w * 0.8, true)
			ci.draw_arc(Vector2(center.x + s * 0.27, top + s * 0.14), s * 0.12, -PI * 0.5, PI * 0.5, 12, color, w * 0.8, true)
			ci.draw_line(Vector2(center.x, top + s * 0.4), Vector2(center.x, center.y + s * 0.28), color, w, true)
			ci.draw_line(Vector2(center.x - s * 0.2, center.y + s * 0.32), Vector2(center.x + s * 0.2, center.y + s * 0.32), color, w * 1.3, true)
		Kind.SPEAKER_LOW, Kind.SPEAKER_HIGH:
			var body := PackedVector2Array([
				center + Vector2(-s * 0.42, -s * 0.12),
				center + Vector2(-s * 0.26, -s * 0.12),
				center + Vector2(-s * 0.04, -s * 0.32),
				center + Vector2(-s * 0.04, s * 0.32),
				center + Vector2(-s * 0.26, s * 0.12),
				center + Vector2(-s * 0.42, s * 0.12),
			])
			ci.draw_colored_polygon(body, color)
			body.append(body[0])
			ci.draw_polyline(body, color, 1.0, true)
			var waves := [0.16] if kind == Kind.SPEAKER_LOW else [0.16, 0.32]
			for r in waves:
				ci.draw_arc(center + Vector2(s * 0.02, 0), s * r, -PI * 0.3, PI * 0.3, 12, color, w * 0.8, true)
		Kind.GRID:
			var cell := s * 0.22
			var step := s * 0.29
			for gy in 3:
				for gx in 3:
					var pos := center + Vector2((gx - 1) * step, (gy - 1) * step) - Vector2(cell, cell) * 0.5
					ci.draw_rect(Rect2(pos, Vector2(cell, cell)), color)
		Kind.CHART:
			var heights := [0.38, 0.62, 0.86]
			var bar := s * 0.18
			for i in 3:
				var bh: float = s * heights[i]
				var x := center.x + (i - 1) * s * 0.3 - bar * 0.5
				ci.draw_rect(Rect2(Vector2(x, center.y + s * 0.43 - bh), Vector2(bar, bh)), color)
		Kind.BULB:
			# Glass as an open ring whose ends run down into the neck, then two base lines.
			var r := s * 0.25
			var glass := center + Vector2(0, -s * 0.1)
			var open := 0.62
			ci.draw_arc(glass, r, PI * 0.5 + open, PI * 2.5 - open, 36, color, w, true)
			var left := glass + Vector2.from_angle(PI * 0.5 + open) * r
			var right := glass + Vector2.from_angle(PI * 0.5 - open) * r
			var neck := center.y + s * 0.2
			ci.draw_line(left, Vector2(left.x, neck), color, w, true)
			ci.draw_line(right, Vector2(right.x, neck), color, w, true)
			ci.draw_line(Vector2(left.x, neck), Vector2(right.x, neck), color, w, true)
			ci.draw_line(Vector2(left.x + w * 0.4, neck + s * 0.13), Vector2(right.x - w * 0.4, neck + s * 0.13), color, w, true)
			for p in [left, right, Vector2(left.x, neck), Vector2(right.x, neck)]:
				ci.draw_circle(p, w * 0.5, color, true, -1.0, true)
		Kind.CHECK:
			var pts := PackedVector2Array([
				center + Vector2(-s * 0.28, 0),
				center + Vector2(-s * 0.08, s * 0.2),
				center + Vector2(s * 0.3, -s * 0.22),
			])
			ci.draw_polyline(pts, color, w * 1.2, true)


## Open ring with a filled arrowhead; clockwise for restart, counter-clockwise for undo.
static func _circular_arrow(ci: CanvasItem, center: Vector2, s: float, w: float, color: Color, clockwise: bool) -> void:
	var r := s * 0.32
	var gap := 0.9
	var a0 := -PI * 0.5 + gap * 0.5
	var a1 := a0 + TAU - gap
	var head_angle := a1 if clockwise else a0
	var trim := 0.35
	ci.draw_arc(center, r, a0 if clockwise else a0 + trim, a1 - trim if clockwise else a1, 40, color, w, true)
	var p := center + Vector2.from_angle(head_angle) * r
	var tangent := Vector2(-sin(head_angle), cos(head_angle)) * (1.0 if clockwise else -1.0)
	var normal := tangent.orthogonal()
	var head := s * 0.2
	var tri := PackedVector2Array([
		p + tangent * head * 0.75,
		p - tangent * head * 0.45 + normal * head * 0.62,
		p - tangent * head * 0.45 - normal * head * 0.62,
	])
	ci.draw_colored_polygon(tri, color)
	tri.append(tri[0])
	ci.draw_polyline(tri, color, 1.5, true)
