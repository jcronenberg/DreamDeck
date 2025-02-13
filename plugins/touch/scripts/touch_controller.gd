class_name TouchController
extends PluginControllerBase
## Controller for handling touch devices.
##
## Provides functions to control touch devices and process the picked devices
## events into touch events.
## NOTE: It can't modify mouse position, so [code]get_local_mouse_position()[/code]
## and [code]get_global_mouse_position()[/code] should be avoided everywhere.

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
var _window_area_min: Vector2 = Vector2(0, 0)  # Top left position of window in current screen.
var _window_area_max: Vector2 = Vector2(0, 0)  # Bottom right position of window in current screen.
var _default_device: String  # Default device string.
var _debug_cursor: ColorRect = null  # Debug cursor instance. Will only be set if in editor.


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


## Ungrabs current device.
func ungrab_device() -> void:
	_grab_touch_devices_script.ungrab_device()


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


# Send touch device events to global [Input] if all necessary conditions are met.
func _handle_event() -> void:
	# This check is necessary because the button down event is the first event
	# if we don't first set x and y it will use the previous position
	if _x_coord > -1 and _y_coord > -1:
		# If window is not fullscreen we have to calculate if the touch was within the area of the window
		# If it wasn't we skip the event
		if (
			_pressed
			and (not (
				(get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN)
				or (get_window().mode == Window.MODE_FULLSCREEN)
			))
			and (
				(_x_coord > _window_area_max.x or _x_coord < _window_area_min.x)
				or (_y_coord > _window_area_max.y or _y_coord < _window_area_min.y)
			)
		):
			return

		Input.parse_input_event(_construct_touch_event())


func _construct_touch_event() -> InputEvent:
	var event: InputEvent
	if not _pressed or _x_diff == 0 and _y_diff == 0:
		event = InputEventScreenTouch.new()
		event.pressed = _pressed
	else:
		event = InputEventScreenDrag.new()
		event.relative = Vector2(_x_diff, _y_diff)
		_x_diff = 0
		_y_diff = 0

	event.position = Vector2(_x_coord, _y_coord) - _window_area_min
	if _debug_cursor:
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


# Calculates [member _window_area_min] and [member _window_area_max].
func _calculate_window_area() -> void:
	_window_area_min = get_window().get_position() - DisplayServer.screen_get_position()
	_window_area_max = (
		get_window().get_position() + get_window().get_size() - DisplayServer.screen_get_position()
	)


func _on_main_window_resized() -> void:
	_calculate_divide_by()
	if not (
		(get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN)
		or (get_window().mode == Window.MODE_FULLSCREEN)
	):
		_calculate_window_area()
