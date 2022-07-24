extends Node

var data
var internal_data

const CONFIG_PATH = "user://config.json"
const INTERNAL_CONFIG_PATH = "user://internal/internal_config.json"

func _ready():
	data = load_config(CONFIG_PATH)
	if not data:
		push_error("Couldn't load config file")
		get_tree().quit()

	ensure_dir_exists("user://internal")
	internal_data = load_config(INTERNAL_CONFIG_PATH)
	if not internal_data:
		push_error("Couldn't load internal config file")


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


func get_config_data():
	return data


func get_internal_config_data():
	return internal_data


# Save the provided data as the internal config
# Callers should make sure they don't overwrite existing data unless they want to
func save_internal_config(new_data):
	var config_file = File.new()

	ensure_dir_exists("user://internal")

	if config_file.open(INTERNAL_CONFIG_PATH, File.WRITE) != OK:
		push_error("Couldn't create file at " + INTERNAL_CONFIG_PATH)
		return false
	config_file.store_line(to_json(new_data))


func ensure_dir_exists(path):
	var dir = Directory.new()
	if dir.open(path) != OK:
		if dir.make_dir(path) != OK:
			push_warning("Couldn't create " + path + " dir")
