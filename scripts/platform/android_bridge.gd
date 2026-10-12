class_name AndroidBridge
extends RefCounted
## Small Android system queries and actions over JNI. Every call returns a neutral answer off
## Android or when the JNI lookup fails, and each lookup sits in its own function, since a failed
## call aborts only that function.

## Upper bound for the phone's font scale: larger sizes would no longer fit the layouts.
const MAX_FONT_SCALE := 1.3
const MIN_FONT_SCALE := 0.85


static func is_android() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton("AndroidRuntime")


## Sends the app to the background the way Android's own Back does on a root screen.
## Returns false when that is not possible here, so the caller can quit instead.
static func move_to_background() -> bool:
	if not is_android():
		return false
	var activity = _activity()
	if activity == null:
		return false
	var runtime = Engine.get_singleton("AndroidRuntime")
	activity.runOnUiThread(runtime.createRunnableFromGodotCallable(_move_task_to_back.bind(activity)))
	return true


static func _move_task_to_back(activity: Variant) -> void:
	activity.moveTaskToBack(true)


## The phone's font size setting (1.0 = default), clamped to what the layouts hold.
static func font_scale() -> float:
	# A failed JNI call aborts the reader and leaves null here.
	var scale: Variant = _read_font_scale() if is_android() else 1.0
	if not scale is float:
		scale = 1.0
	return clampf(scale, MIN_FONT_SCALE, MAX_FONT_SCALE)


static func _read_font_scale() -> float:
	var activity = _activity()
	var settings = JavaClassWrapper.wrap("android.provider.Settings$System")
	if activity == null or settings == null:
		return 1.0
	var scale: float = settings.getFloat(activity.getContentResolver(), "font_scale", 1.0)
	return scale if is_finite(scale) and scale > 0.0 else 1.0


## True when the phone's "remove animations" accessibility setting is on (animator scale 0).
static func animations_off() -> bool:
	if not is_android():
		return false
	var scale: Variant = _read_animator_scale()
	return scale is float and scale == 0.0


static func _read_animator_scale() -> float:
	var activity = _activity()
	var settings = JavaClassWrapper.wrap("android.provider.Settings$Global")
	if activity == null or settings == null:
		return 1.0
	return settings.getFloat(activity.getContentResolver(), "animator_duration_scale", 1.0)


static func _activity() -> Variant:
	return Engine.get_singleton("AndroidRuntime").getActivity()
