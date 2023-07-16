extends CheckButton


func init(ini_name, ini_state):
	text = ini_name
	set_pressed(ini_state)


func return_value():
	return is_pressed()


func return_key():
	return text


func _on_ValueBoolButton_pressed():
	get_node("/root/GlobalSignals").emit_config_changed()


func _on_resized():
	get_node("../..").size.x = size.x
