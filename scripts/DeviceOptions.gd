extends OptionButton

var device_list: Array
# probably tmp, would rather handle this via a saveable setting
export var DefaultDevice: String

onready var grab_touch_devices_script = get_node("/root/GrabTouchDevice")
onready var handler = get_node("/root/HandleTouchEvents")

func get_items():
	device_list = grab_touch_devices_script.call("get_devices")
	self.clear()
	self.add_item("Devices")
	self.set_item_disabled(0, true)
	self.add_separator()
	for i in range(device_list.size()):
		self.add_item(device_list[i], i)
		if DefaultDevice and device_list[i] == DefaultDevice:
			self.select(i + 2)

func _ready():
	get_items()
	if DefaultDevice:
		handler.call_deferred("set_device", DefaultDevice)


func _on_DeviceOptions_item_selected(index):
	handler.call_deferred("set_device", device_list[index - 2])
	$"../GrabCheckButton".pressed = true

# This isn't working as intended, need to have a seperate refresh devices button later
func _on_DeviceOptions_pressed():
	#get_items()
	pass
