extends Node

# Vars
var x_changed: bool = false
var y_changed: bool = false
var event_lmb = InputEventMouseButton.new()
var in_focus: bool = true
var main_window_size: Vector2
var device_max_abs_x: int = 0
var device_max_abs_y: int = 0
var divide_x_by: float = 0.0
var divide_y_by: float = 0.0

# Nodes
var grab_touch_devices_script
onready var config_loader = get_node("/root/ConfigLoader")

func _ready():
	get_tree().get_root().connect("size_changed", self, "_on_main_window_resized")
	# Need to trigger it once on ready to populate values on startup
	_on_main_window_resized()

	event_lmb.button_index = 1
	var config_data = config_loader.get_config_data()
	if config_data.has("settings"):
		if config_data["settings"].has("enable_touch"):
			if config_data["settings"]["enable_touch"] and OS.get_name() == "X11":
				grab_touch_devices_script = load("res://rust/GrabTouchDevice.gdns").new()
				add_child(grab_touch_devices_script)
			elif (config_data["settings"]["enable_touch"]):
				push_error("You have touch enabled, but touch is only available on Linux systems")


func _on_main_window_resized():
	main_window_size = OS.get_real_window_size()
	calculate_divide_by()


func reconnect_device():
	grab_touch_devices_script.call("reconnect_device")


func get_grab_touch_devices_script():
	return grab_touch_devices_script


# These functions are unfortunately necessary as we need to call
# call_deferred() otherwise we run into burrow issues
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
	divide_x_by = device_max_abs_x / main_window_size.x
	divide_y_by = device_max_abs_y / main_window_size.y

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
		Input.parse_input_event(event_lmb)
