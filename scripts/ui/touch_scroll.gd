class_name TouchScroll
extends ScrollContainer
## Vertical scroll area that a finger can drag from anywhere on its content, controls included.
##
## ScrollContainer only sees a touch that its content lets through, and panels and plain Controls
## stop touches by default, so the page scrolled only when a swipe started in a gap between
## cards. Once built, every control inside is switched to pass touches on; buttons, selectors and
## sliders then drop their press when the scroll begins. The deadzone keeps a slightly shaky tap
## from turning into a scroll that would cancel it.

const DEADZONE := 12


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_deadzone = DEADZONE


func _ready() -> void:
	# Deferred so content built in the owners' own _ready is covered too.
	_pass_touches.call_deferred()


func _pass_touches() -> void:
	for c: Control in find_children("*", "Control", true, false):
		if c.mouse_filter == Control.MOUSE_FILTER_STOP:
			c.mouse_filter = Control.MOUSE_FILTER_PASS
