extends Resource

var config: Dictionary
var path: String
var filename: String

const conf_lib := preload("res://scripts/libraries/ConfLib.gd")


func _init(initial_config, initial_path):
	config = initial_config
	path = initial_path.get_base_dir() + "/"
	filename = initial_path.trim_prefix(path)


func load_config():
	conf_lib.ensure_dir_exists(path)
	conf_lib.conf_merge(config, conf_lib.load_config(path + filename))


func save() -> bool:
	conf_lib.ensure_dir_exists(path)
	return conf_lib.save_config(path + filename, config)


func change_config(new_config):
	conf_lib.conf_merge(config, new_config)


func get_config() -> Dictionary:
	return config
