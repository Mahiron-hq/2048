class_name Haptics
extends RefCounted
## Tactile feedback that is actually felt on phones.
##
## Android 12+ files a vibration without attributes under a usage the user may have muted
## (touch or notification feedback), so the game's buzzes could be dropped entirely. Everything
## therefore goes through the system Vibrator with VibrationAttributes.USAGE_MEDIA, which Android
## documents as the usage for games and interactive media. UI taps use the device's predefined
## effects (tuned per actuator); merges and the game-over wave are one-shots and waveforms whose
## amplitude and length both grow, so the steps are felt with or without amplitude control.
## Other platforms use Input.vibrate_handheld.
##
## A JNI call that fails aborts only the GDScript function making it, so every optional effect is
## built in its own function and falls back to a predefined click; the base path never depends
## on it.

enum Kind { TICK, LIGHT }

enum AndroidState { UNKNOWN, READY, FAILED }

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
## Amplitude grows geometrically (equal perceived steps); length grows with it, which is what
## carries the strength on actuators without amplitude control.
const MERGE_AMPLITUDE := Vector2i(60, 255)
const MERGE_MS := Vector2i(20, 60)

## Game over: one second of medium-soft vibration in two swells, the second 1.5 times as long,
## with a short pause between them.
const WAVE_SWELL_SEGMENTS := [12, 18]
const WAVE_SEGMENT_MS := 32
const WAVE_PAUSE_MS := 40
const WAVE_AMPLITUDE := Vector2i(50, 120)

static var _vibrator = null
static var _attributes = null
static var _effect_class = null
static var _effects := {}
static var _merge_effects := {}
static var _wave_effect = null
static var _wave_built := false
static var _android := AndroidState.UNKNOWN


## Plays a short UI feedback of [param kind].
static func play(kind: Kind) -> void:
	if OS.get_name() == "Android" and _android_available():
		_vibrate(_effects[kind])
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
			# Stored before building so a failing build is not retried on every merge.
			_merge_effects[level] = null
			_merge_effects[level] = _make_merge_effect(strength)
		_vibrate(_merge_effects[level])
		return
	Input.vibrate_handheld(merge_ms(strength), lerpf(0.25, 1.0, strength))


## One second of soft, wavy vibration when the game is lost.
static func game_over() -> void:
	if OS.get_name() == "Android" and _android_available():
		if not _wave_built:
			_wave_built = true
			_wave_effect = _make_wave_effect()
		_vibrate(_wave_effect)
		return
	Input.vibrate_handheld(1000, WAVE_AMPLITUDE.y / 255.0)


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


static func merge_ms(strength: float) -> int:
	return roundi(lerpf(MERGE_MS.x, MERGE_MS.y, strength))


## Segment lengths of the game-over waveform: each swell's segments, with a pause between swells.
static func wave_timings() -> PackedInt64Array:
	var out := PackedInt64Array()
	for swell in WAVE_SWELL_SEGMENTS.size():
		if swell > 0:
			out.append(WAVE_PAUSE_MS)
		for i in WAVE_SWELL_SEGMENTS[swell]:
			out.append(WAVE_SEGMENT_MS)
	return out


## Amplitudes matching [method wave_timings]: each swell rises and falls, pauses are 0.
static func wave_amplitudes() -> PackedInt32Array:
	var out := PackedInt32Array()
	for swell in WAVE_SWELL_SEGMENTS.size():
		if swell > 0:
			out.append(0)
		var segments: int = WAVE_SWELL_SEGMENTS[swell]
		for i in segments:
			var t := (i + 0.5) / segments
			out.append(roundi(lerpf(WAVE_AMPLITUDE.x, WAVE_AMPLITUDE.y, sin(PI * t))))
	return out


static func _make_merge_effect(strength: float):
	return _effect_class.createOneShot(merge_ms(strength), merge_amplitude(strength))


static func _make_wave_effect():
	return _effect_class.createWaveform(wave_timings(), wave_amplitudes(), -1)


## Plays [param effect], or the predefined click when it could not be built.
static func _vibrate(effect) -> void:
	if effect == null:
		effect = _effects[Kind.LIGHT]
	if _attributes != null:
		_vibrator.vibrate(effect, _attributes)
	else:
		_vibrator.vibrate(effect)


static func _android_available() -> bool:
	if _android == AndroidState.UNKNOWN:
		# Stays FAILED if initialization returns false or aborts on a JNI error.
		_android = AndroidState.FAILED
		if _init_android():
			_android = AndroidState.READY
	return _android == AndroidState.READY


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
	_effect_class = effect_class
	_vibrator = vibrator
	return true
