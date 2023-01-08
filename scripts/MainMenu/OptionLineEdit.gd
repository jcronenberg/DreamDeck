extends Control

var type: int

var key_node
var value_node


func init(ini_key, ini_value):
	key_node = get_node("Key")
	value_node = get_node("Value")
	if ini_key: key_node.text = ini_key
	if ini_value: value_node.text = str(ini_value)
	type = typeof(ini_value)


func return_value():
	var ret_val = value_node.text
	match type:
		TYPE_REAL:
			if ret_val.is_valid_float():
				return ret_val.to_float()
		TYPE_STRING:
			return ret_val
	return null


func return_key():
	return key_node.text


# Because the resizing happens later than init item_rect_changed signal needs to be monitored
func _on_rect_changed():
	# + 16 because of LineEdit theme, that makes it bigger than its actual size
	get_node("../../..").change_submenu_size(rect_size.x + 16)
