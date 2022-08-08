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

	if not config_file.file_exists(path):
		if config_file.open(path, File.WRITE) != OK:
			push_error("Couldn't create file at " + path)
			return false
	else:
		if config_file.open(path, File.READ_WRITE) != OK:
			push_error("Couldn't open file at " + path)
			return false
		var config_json = JSON.parse(config_file.get_as_text())
		if config_json.error == OK:
			config_data = config_json.result
	if not config_data:
		config_data = {}
		config_file.store_line(to_json(config_data))

	return config_data


func plugin_validation(name: String) -> String:
	var conf_dir_path: String = "user://plugins/" + name
	var conf_path: String = conf_dir_path + "/config.json"
	ensure_dir_exists(conf_dir_path)
	return conf_path


# Get a plugin's config
# If no config is present, it creates the file and returns an empty dict
# name: Name of the plugin, for reading/creating the correct dir in user://plugins/
func get_plugin_config(name: String):
	var conf_path := plugin_validation(name)
	return load_config(conf_path)


# Save new data to the plugin's config file
# Old data is completely overwritten, so the caller should make sure all data is present
# name: Name of the plugin, for writing/creating the correct dir in user://plugins/
# new_data: The data to be written, should be parseable by to_json
func save_plugin_config(name: String, new_data) -> bool:
	var conf_path := plugin_validation(name)
	var config_file = File.new()

	# Save new_data
	if config_file.open(conf_path, File.WRITE) != OK:
		push_error("Couldn't create plugin config file for: " + name)
		return false
	config_file.store_line(to_json(new_data))

	return true


func get_config_data():
	return data


func ensure_dir_exists(path):
	var dir = Directory.new()
	if dir.open(path) != OK:
		if dir.make_dir_recursive(path) != OK:
			push_warning("Couldn't create " + path + " dir")
