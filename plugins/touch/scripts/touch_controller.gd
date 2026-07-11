class_name TouchController
extends PluginControllerBase
## Controller for handling touch devices.
##
## Provides functions to control touch devices and process the picked devices
## events into touch events.
## NOTE: It can't modify mouse position, so [code]get_local_mouse_position()[/code]
## and [code]get_global_mouse_position()[/code] should be avoided everywhere.

## Emitted whenever the current device's grabbed state changes, so open
## [Touch] scenes can stay in sync when it's toggled from elsewhere (e.g. an action).
signal grab_state_changed(grabbed: bool)

const PLUGIN_NAME = "Touch"

var _grab_touch_devices_script: GrabTouchDevice = null  # Touch device grabber.
var _x_coord: float = -1  # Absolute X coordinate.
var _y_coord: float = -1  # Absolute Y coordinate.
var _x_diff: float = 0  # X coordinate delta to previous.
var _y_diff: float = 0  # Y coordinate delta to previous.
var _pressed: bool = false  # Touch down state.
var _device_max_abs_x: int = -1  # Device's maximum value for ABS_X events.
var _device_max_abs_y: int = -1  # Device's maximum value for ABS_X events.
var _divide_x_by: float = 0.0  # Amount to divide X by based on screen size and device's max values.
var _divide_y_by: float = 0.0  # Amount to divide Y by based on screen size and device's max values.
var _default_device: String  # Default device string.
var _debug_cursor: ColorRect = null  # Debug cursor instance. Will only be set if in editor.

# Native windows opted in via register_window(); embedded subwindows don't
# need this since they already receive input through the main viewport.
var _registered_windows: Array[Window] = []
# Tracks which window a touch sequence started on, so its touch-up reaches
# the same window even after leaving its bounds.
var _last_target_window: Window = null


func _init() -> void:
	config.add_string("Default Device", "default_device", "")
	plugin_name = PLUGIN_NAME


func _ready() -> void:
	super()

	_grab_touch_devices_script = GrabTouchDevice.new()
	add_child(_grab_touch_devices_script)

	get_tree().get_root().connect("size_changed", _on_main_window_resized)
	# Need to trigger it once on ready to populate values on startup
	_on_main_window_resized()

	if OS.has_feature("editor"):
		_debug_cursor = get_node_or_null("/root/Main/DebugCursor")
		if _debug_cursor:
			_debug_cursor.visible = true


## Overwritten to handle config values.
func handle_config() -> void:
	var data: Dictionary = config.get_as_dict()

	_default_device = data["default_device"]


## Get default device set by config.
func get_default_device() -> String:
	return _default_device


## Try to reconnect current device.
func reconnect_device() -> void:
	_grab_touch_devices_script.reconnect_device()


## Get all allowed/touch devices.
func get_devices() -> PackedStringArray:
	return _grab_touch_devices_script.get_devices()


## Grabs current device.
func grab_device() -> void:
	var ret: Variant = _grab_touch_devices_script.grab_device()
	if typeof(ret) == TYPE_STRING:
		push_warning("Failed grabbing device: " + ret)
	grab_state_changed.emit(is_device_grabbed())


## Ungrabs current device.
func ungrab_device() -> void:
	_grab_touch_devices_script.ungrab_device()
	grab_state_changed.emit(is_device_grabbed())


## Returns whether the current device is grabbed.
func is_device_grabbed() -> bool:
	return _grab_touch_devices_script.is_grabbed()


## Action entrypoint: toggles the grab status of the current device.
## Deferred since actions can be invoked from a background thread (e.g. macro
## buttons run on a worker thread), while grabbing touches the scene tree.
func toggle_grab_device(_blocking: bool) -> void:
	_toggle_grab_device.call_deferred()


func _toggle_grab_device() -> void:
	if is_device_grabbed():
		ungrab_device()
	else:
		grab_device()


## Registers [param window] so touch events inside its bounds are routed to
## it. For native ([code]force_native[/code]) windows only.
func register_window(window: Window) -> void:
	if window in _registered_windows:
		return
	_registered_windows.append(window)


## Unregisters a window previously passed to [method register_window].
func unregister_window(window: Window) -> void:
	_registered_windows.erase(window)
	if _last_target_window == window:
		_last_target_window = null


## Tries to set device to [param device_name].[br]
## NOTE: Also tries to grab new device immediately.
func set_device(device_name: String) -> void:
	var ret: Variant = _grab_touch_devices_script.set_device(device_name)
	if typeof(ret) == TYPE_STRING:
		push_warning("Failed setting device: " + ret)
		return
	grab_device()
	_device_max_abs_x = _grab_touch_devices_script.get_device_max_abs_x()
	_device_max_abs_y = _grab_touch_devices_script.get_device_max_abs_y()
	if _device_max_abs_x == -1 or _device_max_abs_y == -1:
		push_warning("Failed to get device's maximum absolute values")
	_calculate_divide_by()


## Function for [GrabTouchDevice] when a ABS_X event was registered.
func abs_x_event(new_x: int) -> void:
	if _x_coord > -1:
		_x_diff = (new_x / _divide_x_by) - _x_coord

	_x_coord = new_x / _divide_x_by
	_handle_event()


## Function for [GrabTouchDevice] when a ABS_Y event was registered.
func abs_y_event(new_y: int) -> void:
	if _y_coord > -1:
		_y_diff = (new_y / _divide_y_by) - _y_coord

	_y_coord = new_y / _divide_y_by
	_handle_event()


## Function for [GrabTouchDevice] when a key was pressed (touch down or up in this case).
func key_event(state: bool) -> void:
	_pressed = state
	_handle_event()


func _handle_event() -> void:
	# This check is necessary because the button down event is the first event
	# if we don't first set x and y it will use the previous position
	if _x_coord <= -1 or _y_coord <= -1:
		return

	var target_window: Window
	if _pressed:
		target_window = _resolve_target_window()
		if not target_window:
			return
		_last_target_window = target_window
	elif _last_target_window and is_instance_valid(_last_target_window):
		# Deliver touch-up to whichever window got the press, even if the
		# coordinate has since left its bounds, to avoid a stuck "pressed" touch.
		target_window = _last_target_window
	elif get_window().mode != Window.MODE_MINIMIZED:
		target_window = get_window()
	else:
		# Unmatched touch-up (e.g. press never landed on a window) while
		# minimized - drop rather than leak to the hidden main window.
		return

	var event: InputEvent = _construct_touch_event(target_window)
	if target_window == get_window():
		# push_input() bypasses the global Input singleton's action/mouse-mask
		# state, which other code (e.g. layout drag) relies on for the main window.
		Input.parse_input_event(event)
	else:
		target_window.push_input(event)


# Registered windows win over the main one since they're expected to sit on
# top. A minimized main window is excluded - its reported geometry is stale.
func _resolve_target_window() -> Window:
	if (
		(get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN)
		or (get_window().mode == Window.MODE_FULLSCREEN)
	):
		return get_window()

	var point: Vector2 = Vector2(_x_coord, _y_coord)
	for window in _registered_windows:
		if is_instance_valid(window) and _window_rect(window).has_point(point):
			return window

	if (get_window().mode != Window.MODE_MINIMIZED) and _window_rect(get_window()).has_point(point):
		return get_window()

	return null


# Screen-local bounds of [param window], in the same frame the touch device's
# coordinates are calibrated against.
func _window_rect(window: Window) -> Rect2:
	return Rect2(window.get_position() - DisplayServer.screen_get_position(), window.get_size())


func _construct_touch_event(target_window: Window) -> InputEvent:
	var event: InputEvent
	if not _pressed or _x_diff == 0 and _y_diff == 0:
		event = InputEventScreenTouch.new()
		event.pressed = _pressed
	else:
		event = InputEventScreenDrag.new()
		event.relative = Vector2(_x_diff, _y_diff)
		_x_diff = 0
		_y_diff = 0

	event.position = Vector2(_x_coord, _y_coord) - _window_rect(target_window).position
	if _debug_cursor and target_window == get_window():
		_debug_cursor.position = event.position

	if not _pressed:
		_x_coord = -1
		_y_coord = -1
		_x_diff = 0
		_y_diff = 0

	return event


# Calculates [member _divide_x_by] and [member _divide_y_by].
func _calculate_divide_by() -> void:
	# If _device_max_abs_{x, y} are not set/failed to set just divide by 1
	if _device_max_abs_x == -1 or _device_max_abs_y == -1:
		_divide_x_by = 1
		_divide_y_by = 1
	_divide_x_by = _device_max_abs_x / float(DisplayServer.screen_get_size().x)
	_divide_y_by = _device_max_abs_y / float(DisplayServer.screen_get_size().y)


func _on_main_window_resized() -> void:
	_calculate_divide_by()
