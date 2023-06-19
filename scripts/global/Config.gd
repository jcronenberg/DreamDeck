extends Resource

var path: String = OS.get_user_data_dir() + "/"

const FILENAME := "config.json"
const DEFAULT_CONFIG := {
	"spotify_panel": {
		"legacy": false,
		"disabled": false,
		"refresh_interval": 1
	},
	"settings": {
		"enable_touch": false,
		"default_device": "",
	}
}

var config: Dictionary

const conf_lib := preload("res://scripts/libraries/ConfLib.gd")


func _init():
	config = DEFAULT_CONFIG


func load_config() -> void:
	conf_lib.ensure_dir_exists(path)
	config.merge(conf_lib.load_config(path + FILENAME), true)


func save() -> bool:
	conf_lib.ensure_dir_exists(path)
	return conf_lib.save_config(path + FILENAME, config)


func change_path(new_path) -> void:
	path = new_path


func get_config() -> Dictionary:
	return config
