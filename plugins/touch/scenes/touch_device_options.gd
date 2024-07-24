class_name TouchDeviceOptions
extends OptionButton

## List of all available valid touch devices.
var device_list: Array

@onready var _controller: TouchController = PluginCoordinator.get_plugin_loader("Touch").get_controller("TouchController")


func _ready():
	set_default_device(_controller.get_default_device())


func populate_devices():
	device_list = _controller.get_devices()
	self.clear()
	self.add_item("Devices")
	self.set_item_disabled(0, true)
	self.add_separator()
	for i in range(device_list.size()):
		self.add_item(device_list[i], i)


func set_default_device(default_device):
	if not device_list:
		populate_devices()

	if default_device == "":
		return

	# This is a hack to enable setting the default_device even if it is not connected
	# TODO: Improve this in the future
	if device_list.has(default_device):
		self.select(device_list.find(default_device) + 2)
	else:
		self.add_item(default_device, len(device_list))
		self.select(len(device_list) + 2)
	_controller.call_deferred("set_device", default_device)


func _on_DeviceOptions_item_selected(index):
	_controller.call_deferred("set_device", device_list[index - 2])
	%GrabCheckButton.button_pressed = true
