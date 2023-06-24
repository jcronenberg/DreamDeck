extends OptionButton

var device_list: Array
var default_device: String

onready var handler = get_node("/root/HandleTouchEvents")
onready var config_loader = get_node("/root/ConfigLoader")

func get_items():
	# This is a weird issue of seemingly being invoked before onready triggers
	if not handler:
		handler = get_node("/root/HandleTouchEvents")

	device_list = handler.get_devices()
	self.clear()
	self.add_item("Devices")
	self.set_item_disabled(0, true)
	self.add_separator()
	for i in range(device_list.size()):
		self.add_item(device_list[i], i)

func set_default_device(device_name):
	default_device = device_name
	# This is a hack to enable setting the default_device even if it is not connected
	# TODO: Improve this in the future
	if device_list.has(default_device):
		self.select(device_list.find(default_device) + 2)
	else:
		self.add_item(default_device, len(device_list))
		self.select(len(device_list) + 2)
	handler.call_deferred("set_device", default_device)

func enable(device_name):
	visible = true
	get_items()
	if device_name:
		set_default_device(device_name)


func _on_DeviceOptions_item_selected(index):
	handler.call_deferred("set_device", device_list[index - 2])
	$"../GrabCheckButton".pressed = true
