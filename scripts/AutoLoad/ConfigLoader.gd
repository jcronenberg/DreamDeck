extends Node

var data

var conf_dir = OS.get_user_data_dir() + "/"
var config_path = conf_dir + "config.json"

const conf_lib = preload("res://scripts/libraries/ConfLib.gd")


func _ready():
	# Parse arguments
	var args := {}
	for argument in OS.get_cmdline_args():
		if argument.find("=") > -1:
			var key_value = argument.split("=")
			args[key_value[0].lstrip("--")] = key_value[1]

	if args.has("confdir"):
		conf_dir = args["confdir"] + "/"
		config_path = conf_dir + "config.json"

	# Initial loading of the global config
	data = conf_lib.load_config(config_path)
	if not data:
		push_error("Couldn't load config file")
		get_tree().quit()


# Prepares everything for the plugin config
# ensures directory exists and returns the config's path
func plugin_conf_preparation(name: String) -> String:
	var plugin_conf_dir_path: String = conf_dir + "plugins/" + name
	var plugin_conf_path: String = plugin_conf_dir_path + "/config.json"
	conf_lib.ensure_dir_exists(plugin_conf_dir_path)
	return plugin_conf_path


# Get a plugin's config
# If no config is present, it creates the file and returns an empty dict
# name: Name of the plugin, for reading/creating the correct dir in conf_dir/plugins/
func get_plugin_config(name: String):
	var plugin_conf_path := plugin_conf_preparation(name)
	return conf_lib.load_config(plugin_conf_path)


# Save new data to the plugin's config file
# Old data is completely overwritten, so the caller should make sure all data is present
# name: Name of the plugin, for writing/creating the correct dir in conf_dir/plugins/
# new_data: The data to be written, should be parseable by to_json
func save_plugin_config(name: String, new_data) -> bool:
	var plugin_conf_path := plugin_conf_preparation(name)
	return conf_lib.save_config(plugin_conf_path, new_data)


# Returns the global config data
func get_config_data():
	return data


# Returns the directory of all configs, since this can be modified with arguments
# the returned path has a "/" at the end
func get_conf_dir():
	return conf_dir
