extends OptionButton

var device_list: Array
var default_device: String

onready var handler = get_node("/root/HandleTouchEvents")
onready var config_loader = get_node("/root/ConfigLoader")

func get_items(grab_touch_devices_script):
	device_list = grab_touch_devices_script.call("get_devices")
	self.clear()
	self.add_item("Devices")
	self.set_item_disabled(0, true)
	self.add_separator()
	for i in range(device_list.size()):
		self.add_item(device_list[i], i)

func set_default_device():
	var config_data = config_loader.get_config_data()
	if not config_data.has("settings"):
		return
	elif not config_data["settings"].has("default_device"):
		return
	default_device = config_data["settings"]["default_device"]
	# This is a hack to enable setting the default_device even if it is not connected
	# TODO: Improve this in the future
	if device_list.has(default_device):
		self.select(device_list.find(default_device) + 2)
	else:
		self.add_item(default_device, len(device_list))
		self.select(len(device_list) + 2)
	handler.call_deferred("set_device", default_device)

func _ready():
	var grab_touch_devices_script = handler.get_grab_touch_devices_script()
	if not grab_touch_devices_script:
		queue_free()
		return
	get_items(grab_touch_devices_script)
	set_default_device()


func _on_DeviceOptions_item_selected(index):
	handler.call_deferred("set_device", device_list[index - 2])
	$"../GrabCheckButton".pressed = true
