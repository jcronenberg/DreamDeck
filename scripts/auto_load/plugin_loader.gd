extends Node

const FILENAME := "plugins.json"
const DEFAULT_ACTIVATED_PLUGINS := {
	"spotify_panel": false,
	"macroboard": true,
}

const conf_lib := preload("res://scripts/libraries/conf_lib.gd")
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

	activated_plugins = load("res://scripts/global/config.gd").new(DEFAULT_ACTIVATED_PLUGINS, conf_dir + FILENAME)

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
	get_node("/root/GlobalSignals").emit_activated_plugins_changed()


func handle_activated_plugins():
	var activated_plugins_data: Dictionary = activated_plugins.get_config()
	for plugin in activated_plugins_data.keys():
		# Plugin is activated and it wasn't previously loaded
		if activated_plugins_data[plugin] and not plugin in plugin_loaders.keys():
			# TODO maybe catch the case where Loader.gd doesn't exist
			plugin_loaders[plugin] = load("res://plugins/" + plugin + "/loader.gd").new()
			add_child(plugin_loaders[plugin])
			plugin_loaders[plugin].plugin_load()
		# Plugin isn't activated but was previously
		elif not activated_plugins_data[plugin] and plugin in plugin_loaders.keys():
			plugin_loaders[plugin].plugin_unload()
			plugin_loaders[plugin].free()
			plugin_loaders.erase(plugin)

			# If plugin had settings we need to free and delete them from menu
			if plugin in plugin_configs.keys():
				plugin_configs.erase(plugin)
				get_node("/root/Main/MainMenu").edit_plugin_settings()


func get_plugin_config(plugin_name: String, plugin_default_config):
	conf_lib.ensure_dir_exists(plugin_path(plugin_name))

	# We check that plugin_name has a plugin_loader because otherwise
	# there can be race conditions when freeing a plugin.
	# Because the plugin loader will likely call queue_free when unloading
	# but because there may still be nodes connected to the plugin_configs_changed signal,
	# they may attempt to try loading their config, which was already freed
	# then this gets triggered and would allocate a new config for a plugin that is exiting
	if not plugin_name in plugin_loaders.keys():
		return

	if not plugin_name in plugin_configs.keys():
		plugin_configs[plugin_name] = load("res://scripts/global/config.gd").new(plugin_default_config, plugin_path(plugin_name) + "config.json")

	plugin_configs[plugin_name].load_config()
	get_node("/root/Main/MainMenu").edit_plugin_settings()
	return plugin_configs[plugin_name].get_config()


func get_all_plugin_configs() -> Dictionary:
	var configs := {}
	for plugin in plugin_configs.keys():
		configs[plugin] = plugin_configs[plugin].get_config()

	return configs


func change_all_plugin_configs(new_data: Dictionary):
	for plugin in new_data:
		if not plugin in plugin_configs.keys():
			continue
		plugin_configs[plugin].change_config(new_data[plugin])
		plugin_configs[plugin].save()

	get_node("/root/GlobalSignals").emit_plugin_configs_changed()


func save_plugin_config(plugin_name: String, new_data) -> bool:
	conf_lib.ensure_dir_exists(plugin_path(plugin_name))
	plugin_configs[plugin_name].change_config(new_data)
	return plugin_configs[plugin_name].save()


func get_conf_dir(plugin_name: String):
	conf_lib.ensure_dir_exists(plugin_path(plugin_name))
	return plugin_path(plugin_name)


func get_cache_dir(plugin_name: String):
	conf_lib.ensure_dir_exists(conf_dir + "cache/" + plugin_name + "/")
	return conf_dir + "cache/" + plugin_name + "/"


func list_plugins() -> Array:
	var files := []
	var dir = DirAccess.open("res://plugins")
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
func plugin_path(plugin_name) -> String:
	return conf_dir + "plugins/" + plugin_name + "/"


func get_plugin_loader(plugin_name: String):
	var activated_plugins_data: Dictionary = activated_plugins.get_config()
	if not plugin_name in activated_plugins_data or not activated_plugins_data[plugin_name]:
		return null

	return plugin_loaders[plugin_name]
