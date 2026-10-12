class_name Motion
extends RefCounted
## Whether decorative motion is reduced: no confetti, rings, pulses or bounces, and plain fades
## between screens. Tiles still slide, or a move could not be followed.

static var _reduced := false


static func reduced() -> bool:
	return _reduced


## Applies the player's [param mode]; SYSTEM follows the phone's "remove animations" setting.
static func apply(mode: SaveStore.ReduceMotion) -> void:
	match mode:
		SaveStore.ReduceMotion.ON:
			_reduced = true
		SaveStore.ReduceMotion.OFF:
			_reduced = false
		_:
			_reduced = AndroidBridge.animations_off()
