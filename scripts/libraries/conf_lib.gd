class_name ConfLib
extends RefCounted
## Helper class for [Config] and custom configs

## Load config at [param path]. If it doesn't exist a new config is created.
static func load_config(path) -> Dictionary:
	var config_file: FileAccess
	var config_data := {}

	if FileAccess.file_exists(path):
		config_file = FileAccess.open(path, FileAccess.READ)
		if not config_file:
			push_error(FileAccess.get_open_error())
			return {}
		var json = JSON.new()
		var error = json.parse(config_file.get_as_text())
		if error != OK:
			push_error("JSON Parse Error: ", json.get_error_message())
			return {}
		config_data = json.data
	else:
		config_data = {}
		if not save_config(path, config_data):
			push_error("Couldn't create config at " + path)
			return {}

	return config_data


## Save [param new_data] as json at [param path].
static func save_config(path: String, new_data) -> bool:
	var config_file: FileAccess

	# Save new_data
	config_file = FileAccess.open(path, FileAccess.WRITE)
	if not config_file:
		push_error(FileAccess.get_open_error())
		return false
	config_file.store_string(JSON.stringify(new_data, "\t"))

	return true


## Checks if a directory exists, if not it creates it recursively.
static func ensure_dir_exists(path):
	var dir := DirAccess.open(path)
	if not dir:
		if DirAccess.make_dir_recursive_absolute(path) != OK:
			push_warning("Couldn't create " + path + " dir")


## Merges [param dict2] into [param dict1], overwriting the values in [param dict1] recursively for Dictionaries. [br]
## Sanitizes against user input, by only copying if [param dict1] already contains the key and ensuring matching type.
static func conf_merge(dict1: Dictionary, dict2: Dictionary):
	for key in dict2.keys():
		if not dict1.has(key):
			continue
		if typeof(dict1[key]) == TYPE_DICTIONARY:
			conf_merge(dict1[key], dict2[key])
		elif typeof(dict2[key]) == typeof(dict1[key]):
			dict1[key] = dict2[key]
		elif typeof(dict1[key]) == TYPE_INT:
			dict1[key] = int(dict2[key])


## Returns an [Array] with a recursive list of files in [param path] with absolute path.[br]
## Instead of [method DirAccess.get_files_at], that only lists filenames and not absolute path.
static func list_files_in_dir(path: String) -> Array:
	var file_list: Array = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				file_list.append_array(list_files_in_dir(path + "/" + file_name))
			else:
				file_list.append(path + "/" + file_name)
			file_name = dir.get_next()
	else:
		push_error("Failed to access %s" % path)
	return file_list
