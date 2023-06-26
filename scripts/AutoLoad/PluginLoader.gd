extends Node

const FILENAME := "plugins.json"
const DEFAULT_CONFIG := {
	"SpotifyPanel": false,
	"Macroboard": true,
}

var conf_dir: String = OS.get_user_data_dir() + "/"
var config
var plugin_loaders: Dictionary


func _ready():
	config = load("res://scripts/global/Config.gd").new(DEFAULT_CONFIG, conf_dir + FILENAME)

	var new_conf_dir = ArgumentParser.get_arg("confdir")
	if new_conf_dir:
		if not new_conf_dir.ends_with("/"):
			new_conf_dir = new_conf_dir + "/"

		conf_dir = new_conf_dir
		config.change_path(conf_dir)

	discover_plugins()

	config.load_config()

	handle_config()


func discover_plugins():
	var discovered_plugins := list_plugins()
	var new_config: Dictionary = config.get_config()
	for plugin in discovered_plugins:
		# If plugin already exists it would get overwritten, so we need to skip it
		if not plugin in new_config.keys():
			new_config[plugin] = false

	config.change_config(new_config)


func get_config() -> Dictionary:
	return config.get_config()


func change_config(new_data):
	config.change_config(new_data)
	config.save()

	handle_config()


func handle_config():
	var config_data: Dictionary = config.get_config()
	for plugin in config_data.keys():
		if not plugin in plugin_loaders.keys():
			# TODO maybe catch the case where Loader.gd doesn't exist
			plugin_loaders[plugin] = load("res://plugins/" + plugin + "/Loader.gd").new()
			add_child(plugin_loaders[plugin])
		if config_data[plugin]:
			plugin_loaders[plugin].load()
		else:
			plugin_loaders[plugin].unload()


func list_plugins() -> Array:
	var files := []
	var dir := Directory.new()
	dir.open("res://plugins")
	dir.list_dir_begin()

	while true:
		var file := dir.get_next()
		if file == "":
			break
		elif not file.begins_with("."):
			files.append(file)

	dir.list_dir_end()

	return files
