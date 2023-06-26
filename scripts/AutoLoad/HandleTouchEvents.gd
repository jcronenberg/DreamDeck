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
onready var device_options = get_node("/root/Main/VSeparator/MarginContainer/ControlsSeparator/TouchControls/TouchSeparator/DeviceOptions")
onready var reconnect_button = get_node("/root/Main/VSeparator/MarginContainer/ControlsSeparator/TouchControls/TouchSeparator/ReconnectButton")
onready var grab_check_button = get_node("/root/Main/VSeparator/MarginContainer/ControlsSeparator/TouchControls/TouchSeparator/GrabCheckButton")

func _ready():
	get_tree().get_root().connect("size_changed", self, "_on_main_window_resized")
	# Need to trigger it once on ready to populate values on startup
	_on_main_window_resized()

	# Handle for settings changed event
	get_node("/root/GlobalSignals").connect("config_changed", self, "_on_config_changed")

	# Set event_lmb to left mouse button
	event_lmb.button_index = 1

	load_global_config()


func _on_main_window_resized():
	main_window_size = OS.get_real_window_size()
	calculate_divide_by()


func _on_config_changed():
	load_global_config()


func load_global_config():
	var config_data = config_loader.get_config_data()
	# If the config changed and touch is now disabled, remove grab_touch_devices_script
	if not config_data["Touch"]["Enabled"]:
		disable()
	elif config_data["Touch"]["Enabled"] and OS.get_name() == "X11":
		enable(config_data["Touch"]["Default Device"])
	elif (config_data["Touch"]["Enabled"]):
		push_error("You have touch enabled, but touch is only available on Linux systems")
		disable()


func disable():
	device_options.visible = false
	reconnect_button.visible = false
	grab_check_button.visible = false
	if get_child_count() == 1:
		grab_touch_devices_script.queue_free()


func enable(default_device):
	# if already enabled
	if get_child_count() == 1:
		return

	grab_touch_devices_script = load("res://rust/GrabTouchDevice.gdns").new()
	add_child(grab_touch_devices_script)
	device_options.enable(default_device)
	reconnect_button.visible = true
	grab_check_button.visible = true
	grab_check_button.pressed = true


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
