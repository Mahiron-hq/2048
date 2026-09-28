class_name Haptics
extends RefCounted
## Short tactile feedback that is actually felt on phones.
##
## Very short, low-amplitude one-shot pulses (a few ms at 20-35%) are below what most vibration
## motors can render, so the game used to feel silent. On Android 10+ this uses the system's
## predefined haptic effects, which each device tunes for its own actuator; older Android and
## other platforms get default-amplitude pulses of at least MIN_PULSE_MS.

enum Kind { TICK, LIGHT, HEAVY, DOUBLE }

## VibrationEffect.EFFECT_* ids for each kind (EFFECT_TICK, EFFECT_CLICK, EFFECT_HEAVY_CLICK,
## EFFECT_DOUBLE_CLICK).
const PREDEFINED := {Kind.TICK: 2, Kind.LIGHT: 0, Kind.HEAVY: 5, Kind.DOUBLE: 1}
## Fallback pulse lengths; anything much shorter than ~20 ms is not reliably perceptible.
const PULSE_MS := {Kind.TICK: 20, Kind.LIGHT: 30, Kind.HEAVY: 60, Kind.DOUBLE: 90}
const MIN_PULSE_MS := 20
## VibrationEffect.DEFAULT_AMPLITUDE: let the device pick its natural strength.
const DEFAULT_AMPLITUDE := -1

static var _vibrator = null
static var _effects := {}
static var _android_ready := false
static var _android_failed := false


static func play(kind: Kind) -> void:
	if OS.get_name() == "Android" and _play_android(kind):
		return
	Input.vibrate_handheld(maxi(PULSE_MS[kind], MIN_PULSE_MS))


static func _play_android(kind: Kind) -> bool:
	if _android_failed:
		return false
	if not _android_ready and not _init_android():
		_android_failed = true
		return false
	var effect = _effects.get(kind)
	if effect == null:
		return false
	_vibrator.vibrate(effect)
	return true


static func _init_android() -> bool:
	if not Engine.has_singleton("AndroidRuntime"):
		return false
	var activity = Engine.get_singleton("AndroidRuntime").getActivity()
	if activity == null:
		return false
	var vibrator = activity.getSystemService("vibrator")
	if vibrator == null or not vibrator.hasVibrator():
		return false
	var effect_class = JavaClassWrapper.wrap("android.os.VibrationEffect")
	if effect_class == null:
		return false
	var predefined: bool = effect_class.has_java_method("createPredefined")
	for kind in PREDEFINED:
		var effect = effect_class.createPredefined(PREDEFINED[kind]) if predefined \
				else effect_class.createOneShot(PULSE_MS[kind], DEFAULT_AMPLITUDE)
		if effect == null:
			return false
		_effects[kind] = effect
	_vibrator = vibrator
	_android_ready = true
	return true
