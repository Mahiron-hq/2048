class_name HintLevelPicker
extends Control
## The three hint strengths, slid out of the hint bulb by a long press: a column above it on a
## phone held upright, a column below it on a phone held sideways, a row to its right on a tablet.
## Choosing one, a move, or a tap anywhere else slides them back into the bulb.

signal chosen(level: SaveStore.HintLevel)

## UP and DOWN stack the buttons into a column, RIGHT lines them up in a row.
enum Flow { UP, DOWN, RIGHT }

const KEYS: Array[String] = ["HINT_LEVEL_SIMPLE", "HINT_LEVEL_MEDIUM", "HINT_LEVEL_SMART"]
## Delay between the buttons as they slide out, nearest to the bulb first.
const STAGGER := 0.04
## Size of a button while it sits inside the bulb.
const TUCKED := Vector2(0.3, 0.3)

var is_open := false
var _buttons: Array[PillButton] = []
## Raised tray under the buttons, so nothing beneath shows between them.
var _tray := _Tray.new()
var _origin := Vector2.ZERO
var _tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	add_child(_tray)
	for i in KEYS.size():
		var b := PillButton.make(KEYS[i], PillButton.Look.SECONDARY)
		b.pressed.connect(_on_choice.bind(i))
		add_child(b)
		_buttons.append(b)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		close(true)


## Slides the levels out of [param bulb] (a rect in this control's space) along [param flow],
## with [param current] marked.
func open(bulb: Rect2, flow: Flow, current: SaveStore.HintLevel) -> void:
	if _tween:
		_tween.kill()
	for i in _buttons.size():
		var b := _buttons[i]
		b.look = PillButton.Look.PRIMARY if i == current else PillButton.Look.SECONDARY
		b.compact = false
		b._on_skin_changed()
	# A row that runs past the screen's edge tightens its buttons, and stacks them when even
	# that is not enough, so they never cover one another.
	if flow == Flow.RIGHT and not _row_fits(bulb):
		for b in _buttons:
			b.compact = true
		if not _row_fits(bulb):
			for b in _buttons:
				b.compact = false
			flow = Flow.UP if bulb.get_center().y > size.y * 0.5 else Flow.DOWN
	var homes := layout(bulb, flow)
	is_open = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	show()
	_origin = bulb.get_center()
	_tween = create_tween().set_parallel()
	var tray := homes[0]
	for r in homes:
		tray = tray.merge(r)
	tray = tray.grow(Design.SPACE_XS)
	_tray.position = tray.position
	_tray.size = tray.size
	_tray.radius = homes[0].size.y * 0.5 + Design.SPACE_XS
	# The tray unrolls from the side next to the bulb.
	_tray.pivot_offset = (_origin - tray.position).clamp(Vector2.ZERO, tray.size)
	_tray.queue_redraw()
	_tray.modulate.a = 0.0
	_tray.scale = Vector2.ONE if Motion.reduced() else (Vector2(0.2, 1.0) if flow == Flow.RIGHT else Vector2(1.0, 0.2))
	_tween.tween_property(_tray, "modulate:a", 1.0, Design.DUR_BASE)
	_tween.tween_property(_tray, "scale", Vector2.ONE, Design.DUR_SLOW).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in _buttons.size():
		var b := _buttons[i]
		b.size = homes[i].size
		b.pivot_offset = b.size * 0.5
		b.modulate.a = 0.0
		if Motion.reduced():
			b.position = homes[i].position
			b.scale = Vector2.ONE
			_tween.tween_property(b, "modulate:a", 1.0, Design.DUR_BASE)
			continue
		b.position = _origin - b.size * 0.5
		b.scale = TUCKED
		var delay := i * STAGGER
		_tween.tween_property(b, "position", homes[i].position, Design.DUR_SLOW).set_delay(delay) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(b, "scale", Vector2.ONE, Design.DUR_SLOW).set_delay(delay) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(b, "modulate:a", 1.0, Design.DUR_BASE).set_delay(delay)


## Slides the buttons back into the bulb, or hides them at once when [param instant].
func close(instant := false) -> void:
	if not is_open:
		return
	is_open = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _tween:
		_tween.kill()
	if instant:
		hide()
		return
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_tray, "modulate:a", 0.0, Design.DUR_BASE)
	if not Motion.reduced():
		var rolled := Vector2(0.2, 1.0) if _tray.size.x > _tray.size.y else Vector2(1.0, 0.2)
		_tween.tween_property(_tray, "scale", rolled, Design.DUR_BASE)
	var last := _buttons.size() - 1
	for i in _buttons.size():
		var b := _buttons[i]
		var delay := (last - i) * STAGGER
		if Motion.reduced():
			_tween.tween_property(b, "modulate:a", 0.0, Design.DUR_FAST)
			continue
		_tween.tween_property(b, "position", _origin - b.size * 0.5, Design.DUR_BASE).set_delay(delay)
		_tween.tween_property(b, "scale", TUCKED, Design.DUR_BASE).set_delay(delay)
		_tween.tween_property(b, "modulate:a", 0.0, Design.DUR_BASE).set_delay(delay)
	_tween.chain().tween_callback(hide)


## Where each button rests for [param bulb] and [param flow], nearest to the bulb first, kept
## inside this control and never to the left of the bulb unless the screen's edge leaves no room.
func layout(bulb: Rect2, flow: Flow) -> Array[Rect2]:
	var gap := Design.SPACE_SM
	var h := 0.0
	var widest := 0.0
	for b in _buttons:
		var m := b.get_combined_minimum_size()
		h = maxf(h, m.y)
		widest = maxf(widest, m.x)
	var out: Array[Rect2] = []
	match flow:
		Flow.UP:
			var x := bulb.position.x + Design.SPACE_SM
			for i in _buttons.size():
				out.append(Rect2(x, bulb.position.y - (i + 1) * (h + gap), widest, h))
		Flow.DOWN:
			var x := bulb.position.x + Design.SPACE_SM
			for i in _buttons.size():
				out.append(Rect2(x, bulb.end.y + gap + i * (h + gap), widest, h))
		Flow.RIGHT:
			var x := bulb.end.x + gap
			for b in _buttons:
				var w := b.get_combined_minimum_size().x
				out.append(Rect2(x, bulb.get_center().y - h * 0.5, w, h))
				x += w + gap
	var margin := Design.SPACE_SM
	for i in out.size():
		var r := out[i]
		r.position.x = clampf(r.position.x, margin, maxf(margin, size.x - r.size.x - margin))
		r.position.y = clampf(r.position.y, margin, maxf(margin, size.y - r.size.y - margin))
		out[i] = r
	return out


## The rounded raised surface behind the buttons.
class _Tray:
	extends Control

	var radius := Design.RADIUS_LG

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _on_skin_changed() -> void:
		queue_redraw()

	func _draw() -> void:
		draw_style_box(Design.surface_box(Palette.current.surface, radius, 2), Rect2(Vector2.ZERO, size))


func _row_fits(bulb: Rect2) -> bool:
	var gap := Design.SPACE_SM
	var width := gap * (_buttons.size() - 1)
	for b in _buttons:
		width += b.get_combined_minimum_size().x
	return bulb.end.x + gap + width <= size.x - Design.SPACE_SM


func _gui_input(event: InputEvent) -> void:
	# A touch anywhere but on the buttons puts them away; the touch itself goes no further.
	if event is InputEventMouseButton and event.pressed:
		close()
		accept_event()


func _on_choice(i: int) -> void:
	close()
	chosen.emit(i as SaveStore.HintLevel)
