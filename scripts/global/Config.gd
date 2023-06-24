extends Resource

var path: String = OS.get_user_data_dir() + "/"

const FILENAME := "config.json"
const DEFAULT_CONFIG := {
	"Spotify Panel": {
		"Legacy": false,
		"Disabled": true,
		"Refresh Interval": 1.0
	},
	"Touch": {
		"Enabled": false,
		"Default Device": "",
	},
	"Transparent Background": false,
}

var config: Dictionary

const conf_lib := preload("res://scripts/libraries/ConfLib.gd")


func _init():
	config = DEFAULT_CONFIG


func load_config():
	conf_lib.ensure_dir_exists(path)
	conf_lib.conf_merge(config, conf_lib.load_config(path + FILENAME))


func save() -> bool:
	conf_lib.ensure_dir_exists(path)
	return conf_lib.save_config(path + FILENAME, config)


func change_path(new_path):
	path = new_path


func change_config(new_config):
	conf_lib.conf_merge(config, new_config)


func get_config() -> Dictionary:
	return config
