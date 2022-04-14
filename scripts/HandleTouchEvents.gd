extends Node

# Vars
var x_changed: bool = false
var y_changed: bool = false
var event_lmb = InputEventMouseButton.new()
var in_focus: bool = true

# Nodes
onready var grab_touch_devices_script = get_node("/root/GrabTouchDevice")
onready var device_options: OptionButton = get_node("/root/Main/DeviceOptions")

func _ready():
	event_lmb.button_index = 1
	#grab_touch_devices_script.call("ungrab_device")
	#grab_touch_devices_script.call("grab_device")
	#print(device_list)

# These functions are unfortunately necessary as we need to call
# call_deferred() otherwise we run into burrow issues
func grab_device():
	grab_touch_devices_script.call("grab_device")

func ungrab_device():
	grab_touch_devices_script.call("ungrab_device")

func set_device(device_name):
	grab_touch_devices_script.call("set_device", device_name)

func x_coord_event(new_x):
	event_lmb.position.x = new_x
	x_changed = true
	handle_event()

func y_coord_event(new_y):
	event_lmb.position.y = new_y
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
