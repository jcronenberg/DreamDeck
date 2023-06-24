extends Button

var function: String
var function_node_path


func init(ini_name, ini_function_node_path, ini_function):
	text = ini_name
	function = ini_function
	function_node_path = ini_function_node_path


func _on_ExecuteFunctionButton_pressed():
	get_node(function_node_path).call(function)
