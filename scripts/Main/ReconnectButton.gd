extends Button

onready var handler = get_node("/root/HandleTouchEvents")


func _on_ReconnectButton_pressed():
	handler.call("reconnect_device")
