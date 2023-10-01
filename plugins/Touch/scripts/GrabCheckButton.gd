extends CheckButton

@onready var handler = get_node("../..")


func _on_GrabCheckButton_toggled(button_pressed_state):
	if button_pressed_state:
		handler.call_deferred("grab_device")
	else:
		handler.call_deferred("ungrab_device")
