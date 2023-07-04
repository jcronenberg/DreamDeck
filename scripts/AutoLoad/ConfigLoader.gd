extends Node

const DEFAULT_CONFIG := {
	"Transparent Background": false,
}

var conf_dir: String = OS.get_user_data_dir() + "/"

const conf_lib := preload("res://scripts/libraries/ConfLib.gd")
var config

onready var ArgumentParser := get_node("/root/ArgumentParser")


func _ready():
	var new_conf_dir = ArgumentParser.get_arg("confdir")
	if new_conf_dir:
		if not new_conf_dir.ends_with("/"):
			new_conf_dir = new_conf_dir + "/"

		conf_dir = new_conf_dir

	config = load("res://scripts/global/Config.gd").new(DEFAULT_CONFIG, conf_dir + "config.json")

	# Now that path is set if it is changed we can load
	config.load_config()

	# Initial loading of the global config
	if not config.get_config():
		push_error("Couldn't load config")
		get_tree().quit()


# Returns the global config data
func get_config():
	return config.get_config()


func change_config(new_data):
	if new_data.hash() == config.get_config().hash():
		return
	config.change_config(new_data)
	save_config()
	get_node("/root/GlobalSignals").global_config_changed()


func save_config():
	config.save()


# Returns the directory of all configs, since this can be modified with arguments
# the returned path has a "/" at the end
func get_conf_dir():
	return conf_dir


func on_config_changed():
	get_node("/root/GlobalSignals").config_changed()
