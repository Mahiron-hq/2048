class_name DisplayRate
extends RefCounted
## Refresh rate discovery and the game's frame rate request.
##
## Android keeps apps at 60 Hz on faster panels unless they ask, and Godot has no setting for that
## with the Compatibility renderer, so the request goes through Surface.setFrameRate (API 30+).
## Each JNI lookup runs in its own function, since a failed call aborts only that function.

const FRAME_RATE_COMPATIBILITY_DEFAULT := 0
const CHANGE_FRAME_RATE_ALWAYS := 1
## Frame caps the settings can offer; 0 (no cap) is always offered as well.
const LIMITS := [30, 60, 90, 120]
## Offered on every device: any panel can show them evenly.
const ALWAYS_OFFERED := [30, 60]
## Panels report rates like 120.00001; a rate this close to a whole multiple of a cap counts.
const MULTIPLE_TOLERANCE := 0.02

static var _limit := 0
## Guards the two fields below: the Android query writes them on the UI thread.
static var _lock := Mutex.new()
## Refresh rates of the display modes at the current resolution, highest first. Empty until the
## Android query has run, and on other platforms.
static var _panel_rates := PackedFloat32Array()
## The system's peak refresh rate setting, or 0 when there is none or it cannot be read.
static var _system_peak := 0.0


## Caps the game at [param limit] FPS (0: no cap) and asks the OS for a matching refresh rate.
static func apply(limit: int) -> void:
	_limit = limit
	Engine.max_fps = limit
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return
	var runtime = Engine.get_singleton("AndroidRuntime")
	var activity = runtime.getActivity()
	if activity == null:
		return
	var runnable = runtime.createRunnableFromGodotCallable(_apply.bind(activity))
	activity.runOnUiThread(runnable)


## Refresh rates of the panel's modes, highest first; empty when unknown.
static func panel_rates() -> PackedFloat32Array:
	_lock.lock()
	var rates := _panel_rates.duplicate()
	_lock.unlock()
	if rates.is_empty() and DisplayServer.screen_get_refresh_rate() > 0.0:
		rates.append(DisplayServer.screen_get_refresh_rate())
	return rates


## Highest refresh rate the panel supports, or 0 when unknown.
static func panel_max() -> float:
	var rates := panel_rates()
	return rates[0] if not rates.is_empty() else 0.0


## Highest refresh rate the game can get: the panel's, lowered by the system setting if any.
static func max_rate() -> float:
	var top := panel_max()
	_lock.lock()
	var peak := _system_peak
	_lock.unlock()
	if peak > 0.0 and top > 0.0:
		top = minf(top, peak)
	return top


## Frame caps to offer on this device, ending with 0 (no cap).
static func limit_options() -> Array[int]:
	return options_for(panel_rates())


## Caps for a panel with [param rates]: 30 and 60 always, a higher one only when a mode runs at
## a whole multiple of it (90 on a 120 Hz panel would stutter). Ends with 0, no cap.
static func options_for(rates: PackedFloat32Array) -> Array[int]:
	var out: Array[int] = []
	for limit: int in LIMITS:
		if ALWAYS_OFFERED.has(limit) or _fits_evenly(limit, rates):
			out.append(limit)
	out.append(0)
	return out


static func _fits_evenly(limit: int, rates: PackedFloat32Array) -> bool:
	for rate in rates:
		var ratio := rate / limit
		if ratio >= 1.0 - MULTIPLE_TOLERANCE and absf(ratio - roundf(ratio)) <= MULTIPLE_TOLERANCE:
			return true
	return false


## Runs on the Android UI thread; only JNI calls, no scene access.
static func _apply(activity) -> void:
	var display = activity.getDisplay() if activity.has_java_method("getDisplay") else null
	if display == null:
		var wm = activity.getWindowManager()
		display = wm.getDefaultDisplay() if wm != null else null
	if display == null:
		return
	_read_panel_rates(display)
	_read_system_peak(activity)
	var target := float(_limit)
	if target <= 0.0:
		_lock.lock()
		target = _panel_rates[0] if not _panel_rates.is_empty() else 0.0
		_lock.unlock()
	if target <= 0.0:
		target = display.getRefreshRate()
	var surface = _find_render_surface(activity.getWindow().getDecorView())
	if surface == null or not surface.has_java_method("setFrameRate"):
		return
	# Display.getRoundedCorner marks API 31, where the strategy argument (and ALWAYS) exists.
	if display.has_java_method("getRoundedCorner"):
		surface.setFrameRate(target, FRAME_RATE_COMPATIBILITY_DEFAULT, CHANGE_FRAME_RATE_ALWAYS)
	else:
		surface.setFrameRate(target, FRAME_RATE_COMPATIBILITY_DEFAULT)


static func _read_panel_rates(display) -> void:
	var modes = display.getSupportedModes()
	var current = display.getMode()
	if modes == null or current == null:
		return
	var rates := PackedFloat32Array()
	for mode in modes:
		var same_size: bool = mode.getPhysicalWidth() == current.getPhysicalWidth() \
				and mode.getPhysicalHeight() == current.getPhysicalHeight()
		var rate: float = mode.getRefreshRate()
		if same_size and rate > 0.0 and not rates.has(rate):
			rates.append(rate)
	rates.sort()
	rates.reverse()
	_lock.lock()
	_panel_rates = rates
	_lock.unlock()


## "peak_refresh_rate" is the AOSP key behind the system refresh rate choice; vendors without it
## leave the peak unknown.
static func _read_system_peak(activity) -> void:
	_set_system_peak(0.0)
	var settings = JavaClassWrapper.wrap("android.provider.Settings$System")
	if settings == null:
		return
	var peak: float = settings.getFloat(activity.getContentResolver(), "peak_refresh_rate", 0.0)
	if peak > 0.0 and is_finite(peak):
		_set_system_peak(peak)


static func _set_system_peak(peak: float) -> void:
	_lock.lock()
	_system_peak = peak
	_lock.unlock()


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
