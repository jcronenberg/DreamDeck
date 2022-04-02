extends OptionButton

var device_list: Array
# probably tmp, would rather handle this via a saveable setting
export var DefaultDevice: String

onready var grab_touch_devices_script = get_node("/root/GrabTouchDevice")

func _ready():
	device_list = grab_touch_devices_script.call("get_devices")
	for i in range(device_list.size()):
		self.add_item(device_list[i], i)

	if DefaultDevice:
		grab_touch_devices_script.call("set_device", DefaultDevice)


func _on_DeviceOptions_item_selected(index):
	grab_touch_devices_script.call("set_device", device_list[index])
	# TODO: probably need to set GrabCheckButton to true or smth
