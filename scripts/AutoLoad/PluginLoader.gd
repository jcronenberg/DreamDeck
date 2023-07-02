extends Node

const FILENAME := "plugins.json"
const DEFAULT_CONFIG := {
	"SpotifyPanel": false,
	"Macroboard": true,
}

const conf_lib := preload("res://scripts/libraries/ConfLib.gd")
var conf_dir: String = OS.get_user_data_dir() + "/"
var config
var plugin_loaders: Dictionary
var plugin_configs: Dictionary


func _ready():
	var new_conf_dir = ArgumentParser.get_arg("confdir")
	if new_conf_dir:
		if not new_conf_dir.ends_with("/"):
			new_conf_dir = new_conf_dir + "/"

		conf_dir = new_conf_dir

	config = load("res://scripts/global/Config.gd").new(DEFAULT_CONFIG, conf_dir + FILENAME)

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


func get_plugin_config(name: String, plugin_default_config):
	conf_lib.ensure_dir_exists(plugin_path(name))
	if not name in plugin_configs.keys():
		plugin_configs[name] = load("res://scripts/global/Config.gd").new(plugin_default_config, plugin_path(name) + "config.json")

	plugin_configs[name].load_config()
	get_node("/root/Main/MainMenu").edit_plugin_options()
	return plugin_configs[name].get_config()


func get_all_plugin_configs() -> Dictionary:
	var configs := {}
	for plugin in plugin_configs.keys():
		configs[plugin] = plugin_configs[plugin].get_config()

	return configs


func change_all_plugin_configs(new_data: Dictionary):
	for plugin in new_data:
		plugin_configs[plugin].change_config(new_data[plugin])
		plugin_configs[plugin].save()


func save_plugin_config(name: String, new_data) -> bool:
	conf_lib.ensure_dir_exists(plugin_path(name))
	plugin_configs[name].change_config(new_data)
	return plugin_configs[name].save()


func get_conf_dir(name: String):
	conf_lib.ensure_dir_exists(plugin_path(name))
	return plugin_path(name)


func get_cache_dir(name: String):
	conf_lib.ensure_dir_exists(conf_dir + "cache/" + name + "/")
	return conf_dir + "cache/" + name + "/"


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


# Has trailing slash
func plugin_path(name) -> String:
	return conf_dir + "plugins/" + name + "/"
