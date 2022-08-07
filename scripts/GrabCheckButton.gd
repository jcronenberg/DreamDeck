extends CheckButton

onready var handler = get_node("/root/HandleTouchEvents")


func _ready():
	if not handler.get_grab_touch_devices_script():
		queue_free()


func _on_GrabCheckButton_toggled(button_pressed):
	if button_pressed:
		handler.call_deferred("grab_device")
	else:
		handler.call_deferred("ungrab_device")
