extends OptionButton

var device_list: Array
# probably tmp, would rather handle this via a saveable setting
export var DefaultDevice: String

onready var grab_touch_devices_script = get_node("/root/GrabTouchDevice")
onready var handler = get_node("/root/HandleTouchEvents")

func _ready():
	device_list = grab_touch_devices_script.call("get_devices")
	self.add_item("Devices")
	self.set_item_disabled(0, true)
	self.add_separator()
	for i in range(device_list.size()):
		self.add_item(device_list[i], i)
		if DefaultDevice and device_list[i] == DefaultDevice:
			self.select(i + 2)

	if DefaultDevice:
		handler.call_deferred("set_device", DefaultDevice)


func _on_DeviceOptions_item_selected(index):
	handler.call_deferred("set_device", device_list[index - 2])
	# TODO: probably need to set GrabCheckButton to true or smth
