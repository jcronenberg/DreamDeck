extends Node

var data

const CONFIG_PATH = "user://config.json"

func _ready():
	data = load_config(CONFIG_PATH)
	if not data:
		push_error("Couldn't load config file")
		get_tree().quit()


# Load config at path. If it doesn't exist this create's it
func load_config(path):
	var config_file = File.new()
	var config_data

	if config_file.file_exists(path):
		if config_file.open(path, File.READ) != OK:
			push_error("Couldn't open file at " + path)
			return false
		var config_json = JSON.parse(config_file.get_as_text())
		if config_json.error == OK:
			config_data = config_json.result
		else:
			push_error("Couldn't parse config")
			get_tree().quit()
	else:
		config_data = {}
		if not save_config(path, config_data):
			push_error("Couldn't create config at " + path)
			return false

	return config_data


# Prepares everything for the plugin config
# ensures directory exists and returns the config's path
func plugin_conf_preparation(name: String) -> String:
	var conf_dir_path: String = "user://plugins/" + name
	var conf_path: String = conf_dir_path + "/config.json"
	ensure_dir_exists(conf_dir_path)
	return conf_path


# Get a plugin's config
# If no config is present, it creates the file and returns an empty dict
# name: Name of the plugin, for reading/creating the correct dir in user://plugins/
func get_plugin_config(name: String):
	var conf_path := plugin_conf_preparation(name)
	return load_config(conf_path)


# Save new data to the plugin's config file
# Old data is completely overwritten, so the caller should make sure all data is present
# name: Name of the plugin, for writing/creating the correct dir in user://plugins/
# new_data: The data to be written, should be parseable by to_json
func save_plugin_config(name: String, new_data) -> bool:
	var conf_path := plugin_conf_preparation(name)
	return save_config(conf_path, new_data)


# Returns the global config data
func get_config_data():
	return data


# Save new_data as json at path
# returns true if successful and false if not
func save_config(path: String, new_data) -> bool:
	var config_file = File.new()

	# Save new_data
	if config_file.open(path, File.WRITE) != OK:
		push_error("Couldn't create plugin config file for: " + name)
		return false
	config_file.store_string(JSON.print(new_data, "\t"))

	return true


# Checks if a directory exists, if not it creates it recursively
func ensure_dir_exists(path):
	var dir = Directory.new()
	if dir.open(path) != OK:
		if dir.make_dir_recursive(path) != OK:
			push_warning("Couldn't create " + path + " dir")
