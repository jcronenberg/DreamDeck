extends Control

const PLUGIN_NAME = "Touch"

# Vars
var x_changed: bool = false
var y_changed: bool = false
var event_lmb = InputEventMouseButton.new()
var in_focus: bool = true
var current_screen_size: Vector2
var device_max_abs_x: int = 0
var device_max_abs_y: int = 0
var divide_x_by: float = 0.0
var divide_y_by: float = 0.0

# Nodes
var grab_touch_devices_script
onready var device_options = get_node("ControlsSeparator/DeviceOptions")
onready var reconnect_button = get_node("ControlsSeparator/ReconnectButton")
onready var grab_check_button = get_node("ControlsSeparator/GrabCheckButton")

# Non fullscreen functions
var window_area_min: Vector2 = Vector2(0, 0)
var window_area_max: Vector2 = Vector2(0, 0)

# Config
onready var plugin_loader := get_node("/root/PluginLoader")
const DEFAULT_CONFIG = {
	"Default Device": ""
}


func _ready():
	grab_touch_devices_script = load("res://plugins/Touch/rust/GrabTouchDevice.gdns").new()
	add_child(grab_touch_devices_script)

	get_tree().get_root().connect("size_changed", self, "_on_main_window_resized")
	# Need to trigger it once on ready to populate values on startup
	_on_main_window_resized()

	# Set event_lmb to left mouse button
	event_lmb.button_index = 1

	# Handle default device from plugin config
	load_config()

	if OS.has_feature("editor"):
		get_node("/root/Main/DebugCursor").visible = true


func _on_main_window_resized():
	current_screen_size = OS.get_screen_size()
	calculate_divide_by()
	if not OS.is_window_fullscreen():
		calculate_window_area()


func load_config():
	device_options.set_default_device(plugin_loader.get_plugin_config(PLUGIN_NAME, DEFAULT_CONFIG)["Default Device"])


func calculate_window_area():
	window_area_min = OS.get_window_position() - OS.get_screen_position()
	window_area_max = OS.get_window_position() + OS.get_window_size() - OS.get_screen_position()


func reconnect_device():
	grab_touch_devices_script.call("reconnect_device")


func get_devices():
	return grab_touch_devices_script.call("get_devices")


func grab_device():
	var ret = grab_touch_devices_script.call("grab_device")
	if typeof(ret) == TYPE_STRING:
		push_warning("Failed grabbing device: " + ret)


func ungrab_device():
	grab_touch_devices_script.call("ungrab_device")


func set_device(device_name):
	var ret = grab_touch_devices_script.call("set_device", device_name)
	if typeof(ret) == TYPE_STRING:
		push_warning("Failed setting device: " + ret)
	grab_device()
	device_max_abs_x = grab_touch_devices_script.call("get_device_max_abs_x")
	device_max_abs_y = grab_touch_devices_script.call("get_device_max_abs_y")
	calculate_divide_by()


func calculate_divide_by():
	divide_x_by = device_max_abs_x / current_screen_size.x
	divide_y_by = device_max_abs_y / current_screen_size.y


func x_coord_event(new_x):
	event_lmb.position.x = new_x / divide_x_by
	x_changed = true
	handle_event()


func y_coord_event(new_y):
	event_lmb.position.y = new_y / divide_y_by
	y_changed = true
	handle_event()


func key_event(state):
	event_lmb.pressed = state
	x_changed = false
	y_changed = false
	handle_event()


func handle_event():
	# This check is necessary because the button down event is the first event
	# if we don't first set x and y it will use the previous position
	if !event_lmb.pressed or (x_changed and y_changed):
		# If window is not fullscreen we have to calculate if the touch was within the area of the window
		# If it wasn't we skip the event
		if (not OS.is_window_fullscreen()) and \
			((event_lmb.position.x > window_area_max.x or event_lmb.position.x < window_area_min.x) or \
			 (event_lmb.position.y > window_area_max.y or event_lmb.position.y < window_area_min.y)):
			return

		# We can't modify event_lmb directly as this would also alter future events
		var mod_event = event_lmb.duplicate()
		mod_event.position -= window_area_min
		Input.parse_input_event(mod_event)
		if OS.has_feature("editor"):
			 get_node("/root/Main/DebugCursor").rect_position = mod_event.position
