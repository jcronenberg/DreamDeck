extends Node

var config_data

var conf_dir = OS.get_user_data_dir() + "/"

const conf_lib = preload("res://scripts/libraries/ConfLib.gd")
var config = load("res://scripts/global/Config.gd").new()

onready var ArgumentParser = get_node("/root/ArgumentParser")


func _ready():
	var new_conf_dir = ArgumentParser.get_arg("confdir")
	if new_conf_dir:
		if not new_conf_dir.ends_with("/"):
			new_conf_dir = new_conf_dir + "/"

		conf_dir = new_conf_dir
		config.change_path(conf_dir)

	# Now that path is set if it is changed we can load
	config.load_config()

	# Initial loading of the global config
	config_data = config.get_config()
	if not config_data:
		push_error("Couldn't load config")
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
	return config_data


# Returns the directory of all configs, since this can be modified with arguments
# the returned path has a "/" at the end
func get_conf_dir():
	return conf_dir
