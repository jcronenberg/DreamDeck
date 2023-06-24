extends Reference


# Load config at path. If it doesn't exist this create's it
static func load_config(path) -> Dictionary:
	var config_file = File.new()
	var config_data := {}

	if config_file.file_exists(path):
		if config_file.open(path, File.READ) != OK:
			push_error("Couldn't open file at " + path)
			return {}
		var config_json = JSON.parse(config_file.get_as_text())
		if config_json.error == OK:
			config_data = config_json.result
		else:
			push_error("Couldn't parse config")
			return {}
	else:
		config_data = {}
		if not save_config(path, config_data):
			push_error("Couldn't create config at " + path)
			return {}

	return config_data


# Save new_data as json at path
# returns true if successful and false if not
static func save_config(path: String, new_data) -> bool:
	var config_file = File.new()

	# Save new_data
	if config_file.open(path, File.WRITE) != OK:
		push_error("Couldn't save config file at: " + path)
		return false
	config_file.store_string(JSON.print(new_data, "\t"))

	return true


# Checks if a directory exists, if not it creates it recursively
static func ensure_dir_exists(path):
	var dir = Directory.new()
	if dir.open(path) != OK:
		if dir.make_dir_recursive(path) != OK:
			push_warning("Couldn't create " + path + " dir")


# Merges dict2 into dict1, overwriting the values in dict1 recursively for Dictionaries
# Sanitizes against user input, by only copying if dict1 already contains the key and ensuring matching type
static func conf_merge(dict1: Dictionary, dict2: Dictionary):
	for key in dict2.keys():
		if not dict1.has(key):
			continue
		if typeof(dict1[key]) == TYPE_DICTIONARY:
			conf_merge(dict1[key], dict2[key])
		elif typeof(dict2[key]) == typeof(dict1[key]):
			dict1[key] = dict2[key]
