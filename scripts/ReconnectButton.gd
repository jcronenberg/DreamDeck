extends Button

onready var handler = get_node("/root/HandleTouchEvents")


func _ready():
	if not handler.get_grab_touch_devices_script():
		queue_free()


func _on_ReconnectButton_pressed():
	handler.call("reconnect_device")
