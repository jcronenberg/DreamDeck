extends Node

var _arguments: Dictionary
var _conf_dir: String = OS.get_user_data_dir() + "/"


func _init():
	_arguments = _parse_arguments()

	var new_conf_dir = get_arg("confdir")
	if new_conf_dir:
		if not new_conf_dir.ends_with("/"):
			new_conf_dir = new_conf_dir + "/"

		_conf_dir = new_conf_dir


func _parse_arguments() -> Dictionary:
	var args: Dictionary = {}
	for arg in OS.get_cmdline_args():
		if arg.find("=") > -1:
			var key_value = arg.split("=")
			args[key_value[0].lstrip("--")] = key_value[1]

	return args


## If key is present in given arguments returns the value.
## If it is not present returns null.
func get_arg(key: String):
	if _arguments.has(key):
		return _arguments[key]

	return null


func get_conf_dir() -> String:
	return _conf_dir
