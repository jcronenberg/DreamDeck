extends Node

var _arguments: Dictionary
var _conf_dir: String = OS.get_user_data_dir() + "/"


func _init() -> void:
	_arguments = _parse_arguments()

	var new_conf_dir: String = get_arg("confdir")

	# On Linux/BSD, respect XDG_CONFIG_HOME or use $HOME/.config for config
	if new_conf_dir == "" and OS.get_name() in ["Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		new_conf_dir = OS.get_environment("XDG_CONFIG_HOME")
		if new_conf_dir == "":
			if OS.get_environment("HOME") == "":
				push_error(
					(
						"Failed to get home directory, config is saved in data directory: %s"
						% _conf_dir
					)
				)
				return

			new_conf_dir = OS.get_environment("HOME").path_join(".config")

		new_conf_dir = new_conf_dir.path_join("dreamdeck")

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
func get_arg(key: String) -> String:
	if _arguments.has(key):
		return _arguments[key]

	return ""


func get_conf_dir() -> String:
	return _conf_dir
