class_name TouchScroll
extends ScrollContainer
## Vertical scroll area a finger can drag from anywhere, controls included.
## ScrollContainer only gets touches its content passes on, so every control inside is switched
## to pass; buttons and selectors drop their press once the scroll begins.

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
