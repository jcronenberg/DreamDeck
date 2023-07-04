extends Node

const FILENAME := "plugins.json"
const DEFAULT_ACTIVATED_PLUGINS := {
	"SpotifyPanel": false,
	"Macroboard": true,
}

const conf_lib := preload("res://scripts/libraries/ConfLib.gd")
var conf_dir: String = OS.get_user_data_dir() + "/"
var activated_plugins
var plugin_loaders: Dictionary
var plugin_configs: Dictionary


func _ready():
	var new_conf_dir = ArgumentParser.get_arg("confdir")
	if new_conf_dir:
		if not new_conf_dir.ends_with("/"):
			new_conf_dir = new_conf_dir + "/"

		conf_dir = new_conf_dir

	activated_plugins = load("res://scripts/global/Config.gd").new(DEFAULT_ACTIVATED_PLUGINS, conf_dir + FILENAME)

	discover_plugins()

	activated_plugins.load_config()

	handle_activated_plugins()


func discover_plugins():
	var discovered_plugins := list_plugins()
	var new_activated_plugins: Dictionary = activated_plugins.get_config()
	for plugin in discovered_plugins:
		# If plugin already exists it would get overwritten, so we need to skip it
		if not plugin in new_activated_plugins.keys():
			new_activated_plugins[plugin] = false

	activated_plugins.change_config(new_activated_plugins)


func get_activated_plugins() -> Dictionary:
	return activated_plugins.get_config()


func change_activated_plugins(new_data):
	activated_plugins.change_config(new_data)
	activated_plugins.save()

	handle_activated_plugins()
	get_node("/root/GlobalSignals").activated_plugins_changed()


func handle_activated_plugins():
	var activated_plugins_data: Dictionary = activated_plugins.get_config()
	for plugin in activated_plugins_data.keys():
		if not plugin in plugin_loaders.keys():
			# TODO maybe catch the case where Loader.gd doesn't exist
			plugin_loaders[plugin] = load("res://plugins/" + plugin + "/Loader.gd").new()
			add_child(plugin_loaders[plugin])
		if activated_plugins_data[plugin]:
			plugin_loaders[plugin].load()
		else:
			plugin_loaders[plugin].unload()


func get_plugin_config(name: String, plugin_default_config):
	conf_lib.ensure_dir_exists(plugin_path(name))
	if not name in plugin_configs.keys():
		plugin_configs[name] = load("res://scripts/global/Config.gd").new(plugin_default_config, plugin_path(name) + "config.json")

	plugin_configs[name].load_config()
	get_node("/root/Main/MainMenu").edit_plugin_settings()
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

	get_node("/root/GlobalSignals").plugin_configs_changed()


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
