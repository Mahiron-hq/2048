class_name DisplayRate
extends RefCounted
## Asks the OS to run the game's surface at the panel's highest refresh rate.
##
## Android can keep an app at 60 Hz on 90/120/144 Hz panels unless the app votes for a rate.
## Godot 4.7 exposes no setting for this with the Compatibility renderer, so the vote goes
## through JNI: Surface.setFrameRate (API 30+) on the render view's surface. On iOS the
## equivalent is the display/window/ios/allow_high_refresh_rate project setting.

const FRAME_RATE_COMPATIBILITY_DEFAULT := 0
const CHANGE_FRAME_RATE_ALWAYS := 1

## Highest refresh rate reported by the display, or -1 when unknown.
static var max_rate := -1.0


## Fire-and-forget; safe to call on any platform and to call again after resume.
static func request_max() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return
	var runtime = Engine.get_singleton("AndroidRuntime")
	var activity = runtime.getActivity()
	if activity == null:
		return
	var runnable = runtime.createRunnableFromGodotCallable(_apply.bind(activity))
	activity.runOnUiThread(runnable)


## Runs on the Android UI thread; only JNI calls, no scene access.
static func _apply(activity) -> void:
	var display = activity.getDisplay() if activity.has_java_method("getDisplay") else null
	if display == null:
		var wm = activity.getWindowManager()
		display = wm.getDefaultDisplay() if wm != null else null
	if display == null:
		return
	var best := 0.0
	var modes = display.getSupportedModes()
	var current = display.getMode()
	if modes != null and current != null:
		for mode in modes:
			var same_size: bool = mode.getPhysicalWidth() == current.getPhysicalWidth() \
					and mode.getPhysicalHeight() == current.getPhysicalHeight()
			if same_size:
				best = maxf(best, mode.getRefreshRate())
	if best <= 0.0:
		best = display.getRefreshRate()
	max_rate = best
	var surface = _find_render_surface(activity.getWindow().getDecorView())
	if surface == null or not surface.has_java_method("setFrameRate"):
		return
	# Display.getRoundedCorner marks API 31, where the strategy argument (and ALWAYS) exists.
	if display.has_java_method("getRoundedCorner"):
		surface.setFrameRate(best, FRAME_RATE_COMPATIBILITY_DEFAULT, CHANGE_FRAME_RATE_ALWAYS)
	else:
		surface.setFrameRate(best, FRAME_RATE_COMPATIBILITY_DEFAULT)


static func _find_render_surface(view):
	if view == null:
		return null
	if view.has_java_method("getHolder"):
		var holder = view.getHolder()
		if holder != null:
			var surface = holder.getSurface()
			if surface != null and surface.isValid():
				return surface
	if view.has_java_method("getChildCount"):
		for i in view.getChildCount():
			var found = _find_render_surface(view.getChildAt(i))
			if found != null:
				return found
	return null
