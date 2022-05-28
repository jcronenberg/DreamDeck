extends OptionButton

var device_list: Array
var default_device: String

onready var grab_touch_devices_script = get_node("/root/GrabTouchDevice")
onready var handler = get_node("/root/HandleTouchEvents")
onready var config_loader = get_node("/root/ConfigLoader")

func get_items():
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
	if device_list.has(default_device):
		handler.call_deferred("set_device", default_device)
		self.select(device_list.find(default_device) + 2)

func _ready():
	get_items()
	set_default_device()


func _on_DeviceOptions_item_selected(index):
	handler.call_deferred("set_device", device_list[index - 2])
	$"../GrabCheckButton".pressed = true
