class_name Haptics
extends RefCounted
## Short tactile feedback that is actually felt on phones.
##
## Android 12+ files a vibration without attributes under a usage the user may have muted
## (touch or notification feedback), so the game's buzzes could be dropped entirely. Gameplay
## feedback therefore goes through the system Vibrator with VibrationAttributes.USAGE_MEDIA,
## which Android documents as the usage for games and interactive media, and uses the device's
## predefined haptic effects (tuned per actuator) where available. Older Android gets
## default-amplitude pulses of at least MIN_PULSE_MS; other platforms use Input.vibrate_handheld.

enum Kind { TICK, LIGHT, HEAVY, DOUBLE }

## VibrationEffect.EFFECT_* ids for each kind (EFFECT_TICK, EFFECT_CLICK, EFFECT_HEAVY_CLICK,
## EFFECT_DOUBLE_CLICK).
const PREDEFINED := {Kind.TICK: 2, Kind.LIGHT: 0, Kind.HEAVY: 5, Kind.DOUBLE: 1}
## Fallback pulse lengths; anything much shorter than ~20 ms is not reliably perceptible.
const PULSE_MS := {Kind.TICK: 20, Kind.LIGHT: 30, Kind.HEAVY: 60, Kind.DOUBLE: 90}
const MIN_PULSE_MS := 20
## VibrationEffect.DEFAULT_AMPLITUDE: let the device pick its natural strength.
const DEFAULT_AMPLITUDE := -1
## VibrationAttributes.USAGE_MEDIA.
const USAGE_MEDIA := 19

## Which path is in use, or why the preferred one failed; shown in the FPS overlay for support.
static var status := "not used yet"

static var _vibrator = null
static var _attributes = null
static var _effects := {}
static var _android_ready := false
static var _android_failed := false


static func play(kind: Kind) -> void:
	if OS.get_name() == "Android" and _play_android(kind):
		return
	Input.vibrate_handheld(maxi(PULSE_MS[kind], MIN_PULSE_MS))
	if OS.get_name() != "Android":
		status = "engine pulse"


static func _play_android(kind: Kind) -> bool:
	if _android_failed:
		return false
	if not _android_ready and not _init_android():
		_android_failed = true
		return false
	var effect = _effects.get(kind)
	if effect == null:
		return false
	if _attributes != null:
		_vibrator.vibrate(effect, _attributes)
	else:
		_vibrator.vibrate(effect)
	return true


static func _fail(reason: String) -> bool:
	status = "engine pulse (%s)" % reason
	return false


static func _init_android() -> bool:
	if not Engine.has_singleton("AndroidRuntime"):
		return _fail("no AndroidRuntime")
	var activity = Engine.get_singleton("AndroidRuntime").getActivity()
	if activity == null:
		return _fail("no activity")
	var vibrator = activity.getSystemService("vibrator")
	if vibrator == null:
		return _fail("no vibrator service")
	if not vibrator.hasVibrator():
		return _fail("device has no vibrator")
	var effect_class = JavaClassWrapper.wrap("android.os.VibrationEffect")
	if effect_class == null:
		return _fail("no VibrationEffect")
	var predefined: bool = effect_class.has_java_method("createPredefined")
	for kind in PREDEFINED:
		var effect = effect_class.createPredefined(PREDEFINED[kind]) if predefined \
				else effect_class.createOneShot(PULSE_MS[kind], DEFAULT_AMPLITUDE)
		if effect == null:
			return _fail("effect creation failed")
		_effects[kind] = effect
	var attributes_class = JavaClassWrapper.wrap("android.os.VibrationAttributes")
	if attributes_class != null and attributes_class.has_java_method("createForUsage"):
		_attributes = attributes_class.createForUsage(USAGE_MEDIA)
	_vibrator = vibrator
	_android_ready = true
	status = "%s%s" % ["system effects" if predefined else "pulses", ", media usage" if _attributes != null else ""]
	return true
