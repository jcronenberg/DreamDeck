extends Button

onready var grab_touch_devices_script = get_node("/root/GrabTouchDevice")

func _on_ReconnectButton_pressed():
	grab_touch_devices_script.call("reconnect_device")
