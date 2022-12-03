extends Node

var arguments: Dictionary


func _ready():
	arguments = parse_arguments()


func parse_arguments() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_args():
		if arg.find("=") > -1:
			var key_value = arg.split("=")
			args[key_value[0].lstrip("--")] = key_value[1]

	return args


# If key is present in given arguments returns the value
# If it is not present returns null
func get_arg(key: String):
	if arguments.has(key):
		return arguments[key]

	return null
