extends Node

# Vars
var x_changed: bool = false
var y_changed: bool = false
var event_lmb = InputEventMouseButton.new()
var in_focus: bool = true
var screen_divide_by: float = 1.0

# Nodes
var grab_touch_devices_script
onready var config_loader = get_node("/root/ConfigLoader")

func _ready():
	event_lmb.button_index = 1
	var config_data = config_loader.get_config_data()
	if config_data.has("settings"):
		if config_data["settings"].has("enable_touch"):
			if config_data["settings"]["enable_touch"]:
				grab_touch_devices_script = load("res://rust/GrabTouchDevice.gdns").new()
				add_child(grab_touch_devices_script)
		if config_data["settings"].has("screen_divide_by"):
			screen_divide_by = config_data["settings"]["screen_divide_by"]


func reconnect_device():
	grab_touch_devices_script.call("reconnect_device")


func get_grab_touch_devices_script():
	return grab_touch_devices_script


# These functions are unfortunately necessary as we need to call
# call_deferred() otherwise we run into burrow issues
func grab_device():
	grab_touch_devices_script.call("grab_device")

func ungrab_device():
	grab_touch_devices_script.call("ungrab_device")

func set_device(device_name):
	grab_touch_devices_script.call("set_device", device_name)

func x_coord_event(new_x):
	event_lmb.position.x = new_x / screen_divide_by
	x_changed = true
	handle_event()

func y_coord_event(new_y):
	event_lmb.position.y = new_y / screen_divide_by
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
