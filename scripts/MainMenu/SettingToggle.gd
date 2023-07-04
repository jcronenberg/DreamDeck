extends Button


func init(ini_name, ini_state):
	text = ini_name
	pressed = ini_state


func return_value():
	return pressed


func return_key():
	return text


func _on_ValueBoolButton_pressed():
	get_node("/root/GlobalSignals").config_changed()
