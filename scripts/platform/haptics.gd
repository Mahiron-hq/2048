class_name Haptics
extends RefCounted
## Tactile feedback that is actually felt on phones.
##
## Android 12+ files a vibration without attributes under a usage the user may have muted
## (touch or notification feedback), so the game's buzzes could be dropped entirely. Everything
## therefore goes through the system Vibrator with VibrationAttributes.USAGE_MEDIA, which Android
## documents as the usage for games and interactive media. UI taps use the device's predefined
## effects (tuned per actuator); merges and the game-over wave are built from amplitude-controlled
## one-shots and waveforms, falling back to pulse length alone on actuators without amplitude
## control. Other platforms use Input.vibrate_handheld.

enum Kind { TICK, LIGHT }

## VibrationEffect.EFFECT_TICK and EFFECT_CLICK.
const PREDEFINED := {Kind.TICK: 2, Kind.LIGHT: 0}
## Fallback pulse lengths; anything much shorter than ~20 ms is not reliably perceptible.
const PULSE_MS := {Kind.TICK: 20, Kind.LIGHT: 30}
const MIN_PULSE_MS := 20
## VibrationEffect.DEFAULT_AMPLITUDE: let the device pick its natural strength.
const DEFAULT_AMPLITUDE := -1
## VibrationAttributes.USAGE_MEDIA.
const USAGE_MEDIA := 19

## Merging two tiles of this value is the weakest felt merge; merging 2s is silent.
const MERGE_FIRST_FELT := 4
## Merging two tiles of this value or more gives the strongest buzz.
const MERGE_STRONGEST := 65536
## Merge buzz range with amplitude control: amplitude grows geometrically (equal perceived steps),
## length a little.
const MERGE_AMPLITUDE := Vector2i(36, 255)
const MERGE_MS := Vector2i(16, 42)
## Without amplitude control, only the pulse length can carry the strength.
const MERGE_MS_FIXED_AMPLITUDE := Vector2i(10, 60)

## Game over: one second of medium-soft vibration whose strength swells three times.
const WAVE_SEGMENT_MS := 50
const WAVE_SEGMENTS := 20
const WAVE_CYCLES := 3.0
const WAVE_AMPLITUDE := 90.0
const WAVE_SWING := 35.0
## On/off pattern (starting with "off") for actuators without amplitude control.
const WAVE_PULSES_MS: Array[int] = [0, 140, 60, 140, 60, 140, 60, 140, 60, 140]

static var _vibrator = null
static var _attributes = null
static var _effect_class = null
static var _amplitude_control := false
static var _effects := {}
static var _merge_effects := {}
static var _wave_effect = null
static var _android_ready := false
static var _android_failed := false


## Plays a short UI feedback of [param kind].
static func play(kind: Kind) -> void:
	if OS.get_name() == "Android" and _android_available():
		_vibrate(_effects.get(kind))
		return
	Input.vibrate_handheld(maxi(PULSE_MS[kind], MIN_PULSE_MS))


## Buzzes for a merge of two [param value] tiles, stronger for bigger tiles; silent for 2s.
static func merge(value: int) -> void:
	var level := merge_level(value)
	if level == 0:
		return
	var strength := merge_strength(level)
	if OS.get_name() == "Android" and _android_available():
		if not _merge_effects.has(level):
			_merge_effects[level] = _make_merge_effect(strength)
		_vibrate(_merge_effects[level])
		return
	Input.vibrate_handheld(roundi(lerpf(MERGE_MS.x, MERGE_MS.y, strength)), lerpf(0.15, 1.0, strength))


## One second of soft, wavy vibration when the game is lost.
static func game_over() -> void:
	if OS.get_name() == "Android" and _android_available():
		if _wave_effect == null:
			_wave_effect = _make_wave_effect()
		_vibrate(_wave_effect)
		return
	Input.vibrate_handheld(WAVE_SEGMENT_MS * WAVE_SEGMENTS, WAVE_AMPLITUDE / 255.0)


## Strength step for merging two [param value] tiles: 0 (none) for 2s, 1 for 4s, up to
## [method merge_level_count] for MERGE_STRONGEST and above.
static func merge_level(value: int) -> int:
	if value < MERGE_FIRST_FELT:
		return 0
	var steps := merge_level_count()
	var level := 1
	while level < steps and value >= MERGE_FIRST_FELT << level:
		level += 1
	return level


static func merge_level_count() -> int:
	return roundi(log(float(MERGE_STRONGEST) / MERGE_FIRST_FELT) / log(2.0)) + 1


## 0..1 position of [param level] within the merge range.
static func merge_strength(level: int) -> float:
	return clampf((level - 1) / float(merge_level_count() - 1), 0.0, 1.0)


## Vibration amplitude (1..255) for [param strength], rising by a constant ratio per level.
static func merge_amplitude(strength: float) -> int:
	return roundi(MERGE_AMPLITUDE.x * pow(float(MERGE_AMPLITUDE.y) / MERGE_AMPLITUDE.x, strength))


## Amplitudes of the game-over wave, one per WAVE_SEGMENT_MS, easing in and out at the ends.
static func wave_amplitudes() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in WAVE_SEGMENTS:
		var t := (i + 0.5) / WAVE_SEGMENTS
		var edge := minf(1.0, minf(t, 1.0 - t) * 6.0)
		var a := (WAVE_AMPLITUDE + WAVE_SWING * sin(TAU * WAVE_CYCLES * t)) * lerpf(0.5, 1.0, edge)
		out.append(clampi(roundi(a), 1, 255))
	return out


static func _make_merge_effect(strength: float):
	if _amplitude_control:
		return _effect_class.createOneShot(roundi(lerpf(MERGE_MS.x, MERGE_MS.y, strength)), merge_amplitude(strength))
	var ms := roundi(lerpf(MERGE_MS_FIXED_AMPLITUDE.x, MERGE_MS_FIXED_AMPLITUDE.y, strength))
	return _effect_class.createOneShot(ms, DEFAULT_AMPLITUDE)


static func _make_wave_effect():
	if _amplitude_control:
		var timings := PackedInt64Array()
		timings.resize(WAVE_SEGMENTS)
		timings.fill(WAVE_SEGMENT_MS)
		return _effect_class.createWaveform(timings, wave_amplitudes(), -1)
	return _effect_class.createWaveform(PackedInt64Array(WAVE_PULSES_MS), -1)


static func _vibrate(effect) -> void:
	if effect == null:
		return
	if _attributes != null:
		_vibrator.vibrate(effect, _attributes)
	else:
		_vibrator.vibrate(effect)


static func _android_available() -> bool:
	if _android_ready:
		return true
	if _android_failed:
		return false
	_android_ready = _init_android()
	_android_failed = not _android_ready
	return _android_ready


static func _fail(reason: String) -> bool:
	push_warning("Haptics: falling back to engine pulses (%s)" % reason)
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
	_amplitude_control = vibrator.hasAmplitudeControl() == true
	_effect_class = effect_class
	_vibrator = vibrator
	return true
