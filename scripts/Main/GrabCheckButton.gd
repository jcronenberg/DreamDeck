extends CheckButton

@onready var handler = get_node("../..")


func _on_GrabCheckButton_toggled(button_pressed):
	if button_pressed:
		handler.call_deferred("grab_device")
	else:
		handler.call_deferred("ungrab_device")
