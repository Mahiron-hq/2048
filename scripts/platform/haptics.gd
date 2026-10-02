class_name Haptics
extends RefCounted
## Haptics that reach the player whatever the phone's vibration settings.
##
## Plays through the system Vibrator with USAGE_MEDIA, or USAGE_ACCESSIBILITY while Android 13+'s
## "vibrate_on" switch is off (the only usage it lets through then). Effects suit the motor:
## composed clicks, amplitude pulses or the maker's predefined effects.
## Each JNI call sits in its own function, since a failed call aborts only that function.

enum Kind { TICK, LIGHT }

enum AndroidState { UNKNOWN, READY, FAILED }

## What the phone's motor can do; decides how effects are built.
enum Actuator { PREDEFINED_ONLY, AMPLITUDE, PRIMITIVES }

## VibrationEffect.EFFECT_TICK and EFFECT_CLICK.
const PREDEFINED := {Kind.TICK: 2, Kind.LIGHT: 0}
## Merge tiers on actuators without strength control, lightest first: EFFECT_TEXTURE_TICK,
## EFFECT_TICK, EFFECT_CLICK, EFFECT_HEAVY_CLICK.
const MERGE_TIERS := [21, 2, 0, 5]
## VibrationEffect.Composition.PRIMITIVE_CLICK.
const PRIMITIVE_CLICK := 1
## Fallback pulse lengths; anything much shorter than ~20 ms is not reliably perceptible.
const PULSE_MS := {Kind.TICK: 20, Kind.LIGHT: 30}
const MIN_PULSE_MS := 20
## VibrationEffect.DEFAULT_AMPLITUDE: let the device pick its natural strength.
const DEFAULT_AMPLITUDE := -1
## VibrationAttributes.USAGE_MEDIA and USAGE_ACCESSIBILITY.
const USAGE_MEDIA := 19
const USAGE_ACCESSIBILITY := 66

## Merging two tiles of this value is the weakest felt merge; merging 2s is silent.
const MERGE_FIRST_FELT := 4
## Merging two tiles of this value or more gives the strongest buzz.
const MERGE_STRONGEST := 65536
## Amplitude grows by a constant ratio so the steps feel even; length grows too, for motors
## without amplitude control.
const MERGE_AMPLITUDE := Vector2i(60, 255)
const MERGE_MS := Vector2i(20, 60)
## Composed click scale for the weakest and the strongest merge.
const MERGE_SCALE := Vector2(0.3, 1.0)

## Game over: one second in two soft swells, the second 1.5 times as long.
const WAVE_SWELL_SEGMENTS := [12, 18]
const WAVE_SEGMENT_MS := 32
const WAVE_PAUSE_MS := 40
const WAVE_AMPLITUDE := Vector2i(50, 120)
## Pulse length range of the spaced-pulse wave, per segment, for actuators without amplitude.
const WAVE_PULSE_MS := Vector2i(6, 15)

static var _vibrator = null
static var _media_attributes = null
static var _accessibility_attributes = null
static var _effect_class = null
static var _effects := {}
static var _merge_effects := {}
static var _wave_effect = null
static var _wave_built := false
static var _android := AndroidState.UNKNOWN
static var _actuator := Actuator.PREDEFINED_ONLY
static var _system_switch_off := false


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
			_merge_effects[level] = _make_merge_effect(level, strength)
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


## Re-reads the system vibration switch; call on resume, the player may have changed it.
static func refresh_system_state() -> void:
	if _android == AndroidState.READY:
		_system_switch_off = false
		_read_system_switch()


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


## Predefined effect id for a merge of [param level] on actuators without strength control.
static func merge_tier(level: int) -> int:
	var tier := int(merge_strength(level) * MERGE_TIERS.size())
	return MERGE_TIERS[mini(tier, MERGE_TIERS.size() - 1)]


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


## The wave for on/off-only motors: short pulses, longer where the wave is stronger.
## Alternating off/on durations starting with off, as createWaveform(long[], int) expects.
static func pulse_wave_timings() -> PackedInt64Array:
	var out := PackedInt64Array([0])
	var timings := wave_timings()
	var amplitudes := wave_amplitudes()
	var carried_off := 0
	for i in timings.size():
		if amplitudes[i] == 0:
			carried_off += timings[i]
			continue
		var share := inverse_lerp(WAVE_AMPLITUDE.x, WAVE_AMPLITUDE.y, amplitudes[i])
		var on := roundi(lerpf(WAVE_PULSE_MS.x, WAVE_PULSE_MS.y, clampf(share, 0.0, 1.0)))
		out[out.size() - 1] += carried_off
		out.append(on)
		out.append(timings[i] - on)
		carried_off = 0
	return out


static func _make_merge_effect(level: int, strength: float):
	match _actuator:
		Actuator.PRIMITIVES:
			var composition = _effect_class.startComposition()
			composition.addPrimitive(PRIMITIVE_CLICK, lerpf(MERGE_SCALE.x, MERGE_SCALE.y, strength))
			return composition.compose()
		Actuator.AMPLITUDE:
			return _effect_class.createOneShot(merge_ms(strength), merge_amplitude(strength))
	return _effect_class.createPredefined(merge_tier(level))


static func _make_wave_effect():
	if _actuator == Actuator.PREDEFINED_ONLY:
		return _effect_class.createWaveform(pulse_wave_timings(), -1)
	return _effect_class.createWaveform(wave_timings(), wave_amplitudes(), -1)


## Plays [param effect], or the predefined click when it could not be built.
static func _vibrate(effect) -> void:
	if effect == null:
		effect = _effects[Kind.LIGHT]
	var attributes = _accessibility_attributes if _system_switch_off and _accessibility_attributes != null \
			else _media_attributes
	if attributes != null:
		_vibrator.vibrate(effect, attributes)
	else:
		_vibrator.vibrate(effect)


static func _android_available() -> bool:
	if _android == AndroidState.UNKNOWN:
		# Stays FAILED if initialization returns false or aborts on a JNI error.
		_android = AndroidState.FAILED
		if _init_android():
			_android = AndroidState.READY
			_detect_actuator()
			refresh_system_state()
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
		_media_attributes = attributes_class.createForUsage(USAGE_MEDIA)
		_accessibility_attributes = attributes_class.createForUsage(USAGE_ACCESSIBILITY)
	_effect_class = effect_class
	_vibrator = vibrator
	return true


## Leaves PREDEFINED_ONLY in place if a query fails, the choice that suits every actuator.
static func _detect_actuator() -> void:
	if not _effect_class.has_java_method("createPredefined"):
		_actuator = Actuator.AMPLITUDE
		return
	if _vibrator.has_java_method("areAllPrimitivesSupported") \
			and _vibrator.areAllPrimitivesSupported(PackedInt32Array([PRIMITIVE_CLICK])):
		_actuator = Actuator.PRIMITIVES
	elif _vibrator.hasAmplitudeControl():
		_actuator = Actuator.AMPLITUDE


## Android 13+ mutes every usage but accessibility while "vibrate_on" is 0; older versions
## ignore the switch for apps.
static func _read_system_switch() -> void:
	if OS.get_version().to_int() < 13 or _accessibility_attributes == null:
		return
	var activity = Engine.get_singleton("AndroidRuntime").getActivity()
	var settings = JavaClassWrapper.wrap("android.provider.Settings$System")
	if activity == null or settings == null:
		return
	var vibrate_on: int = settings.getInt(activity.getContentResolver(), "vibrate_on", 1)
	_system_switch_off = vibrate_on == 0
