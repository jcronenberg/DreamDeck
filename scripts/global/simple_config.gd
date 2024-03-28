extends Resource
class_name SimpleConfig
## @deprecated

var config: Dictionary
var path: String
var filename: String


func _init(initial_config, initial_path):
	config = initial_config.duplicate(true)
	path = initial_path.get_base_dir() + "/"
	filename = initial_path.trim_prefix(path)


func load_config():
	ConfLib.ensure_dir_exists(path)
	ConfLib.conf_merge(config, ConfLib.load_config(path + filename).duplicate(true))


func save() -> bool:
	ConfLib.ensure_dir_exists(path)
	return ConfLib.save_config(path + filename, config)


func change_config(new_config):
	ConfLib.conf_merge(config, new_config)


func get_config() -> Dictionary:
	return config
