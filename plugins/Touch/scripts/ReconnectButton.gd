extends Button

@onready var handler = get_node("../..")


func _on_ReconnectButton_pressed():
	handler.call("reconnect_device")
