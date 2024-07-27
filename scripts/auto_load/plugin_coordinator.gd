extends Node

const FILENAME := "plugins.json"
const DEFAULT_ACTIVATED_PLUGINS := {
	"Macroboard": true,
}

var _conf_dir: String = OS.get_user_data_dir() + "/"
var _conf_path: String # Path for plugins.json
var _plugins: Array[Plugin] = []
# _scenes example:
# {"Spotify Panel": {"Spotify Panel1": scene, "Spotify Panel2": scene}, "Macroboard": {"Macroboard": scene}}
var _scenes: Dictionary # The already loaded scenes


@export var layout_setup_finished: bool = false:
	set = set_layout_setup_finished


func _ready():
	var new_conf_dir = ArgumentParser.get_arg("confdir")
	if new_conf_dir:
		if not new_conf_dir.ends_with("/"):
			new_conf_dir = new_conf_dir + "/"

		_conf_dir = new_conf_dir

	_conf_path = _conf_dir + FILENAME

	discover_plugins()

	load_activated_plugins()


## Discovers all plugins at `res://plugins` and adds them to [member _plugins].
## It also loads all files in [member _conf_dir]/plugins as resource packs.
func discover_plugins():
	# FIXME in current godot load_resource_pack breaks DirAccess
	# Thus runtime plugins don't work with the editor.
	# If you need to test something export a debug build and test
	# with that.
	if OS.has_feature("editor"):
		return

	_runtime_load_plugins()

	var discovered_plugins := list_plugins()
	for plugin_path in discovered_plugins:
		var plugin_config: FileAccess = FileAccess.open("res://plugins/%s/plugin.json" % plugin_path,
			FileAccess.READ)
		if not plugin_config:
			push_error("Plugin %s is missing it's plugin.json file" % plugin_path)
			continue

		var plugin_json: Variant = JSON.parse_string(plugin_config.get_as_text())
		if not plugin_json or typeof(plugin_json) != TYPE_DICTIONARY:
			push_error("Failed to parse %s's plugin.json" % plugin_path)
			continue

		_plugins.append(Plugin.new(plugin_json, plugin_path))


func _runtime_load_plugins():
	ConfLib.ensure_dir_exists(_conf_dir + "plugins")
	var file_list = ConfLib.list_files_in_dir(_conf_dir + "plugins")
	for file in file_list:
		if not ProjectSettings.load_resource_pack(file):
			push_error("Failed to load plugin %s" % file)


func get_activated_plugins() -> Array:
	var ret_array: Array = []
	for plugin in _plugins:
		if plugin.is_activated():
			ret_array.push_back(plugin.plugin_name)

	return ret_array


func get_plugin_config() -> Dictionary:
	var ret_dict: Dictionary = {}
	for plugin in _plugins:
		ret_dict[plugin.plugin_name] = plugin.is_activated()
	return ret_dict


func change_activated_plugins(new_data):
	for plugin in _plugins:
		plugin.set_activated(new_data[plugin.plugin_name])

	save_activated_plugins()

	get_tree().call_group("layout_panels", "load_scene")


func save_activated_plugins():
	ConfLib.save_config(_conf_path, get_plugin_config())


func load_activated_plugins():
	var config: Variant = ConfLib.load_config(_conf_path)
	if not config:
		config = DEFAULT_ACTIVATED_PLUGINS
	elif typeof(config) != TYPE_DICTIONARY:
		push_error("Wrong plugins.json config type")
		get_tree().quit(1)

	for plugin in _plugins:
		if config.has(plugin.plugin_name):
			plugin.set_activated(config[plugin.plugin_name])


func get_conf_dir(plugin_name: String) -> String:
	# This ability to just get _conf_dir should maybe be moved to somewhere else in the future
	if plugin_name == "":
		return _conf_dir

	ConfLib.ensure_dir_exists(get_plugin_path(plugin_name))
	return get_plugin_path(plugin_name)


func get_cache_dir(plugin_name: String):
	ConfLib.ensure_dir_exists("%s/cache/%s/" % [_conf_dir, plugin_name.to_snake_case()])
	return "%s/cache/%s/" % [_conf_dir, plugin_name.to_snake_case()]


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


func get_plugin_path(plugin_name) -> String:
	return "%s/plugin_configs/%s/" % [_conf_dir, plugin_name]


## Returns loader of [param plugin_name]. Null if plugin doesn't exist or isn't loaded.
func get_plugin_loader(plugin_name: String) -> PluginLoaderBase:
	for plugin in _plugins:
		if plugin.plugin_name == plugin_name:
			return plugin.get_loader()

	return null


func set_layout_setup_finished(value: bool):
	layout_setup_finished = value

	# If there are already scenes loaded handle them here
	for plugin_name in _scenes:
		_add_scenes_to_panels(plugin_name, _scenes[plugin_name])


## Should be called when a scene of a plugin has loaded and should now be added to the layout.[br]
## [param scene_dict] should be: [code]{scene_name: resource}[/code][br]
func add_scene(plugin_name: String, scene_dict: Dictionary):
	# Store scene
	if _scenes.has(plugin_name):
		_scenes[plugin_name].merge(scene_dict, true)
	else:
		_scenes[plugin_name] = scene_dict

	# If layout setup isn't yet finished, scene will be added once
	# layout sets layout_setup_finished
	if not layout_setup_finished:
		return

	_add_scenes_to_panels(plugin_name, scene_dict)


func _add_scenes_to_panels(plugin_name: String, scene_dict: Dictionary):
	get_tree().call_group("layout_panels", "add_plugin_scene", plugin_name, scene_dict)


## Loads a plugin scene.
## Tries to use cached resources in [member _scenes].
func load_plugin_scene(plugin_name: String, scene: String):
	# If cached in _scenes directly use it
	if _scenes.has(plugin_name) and _scenes[plugin_name].has(scene):
		get_tree().call_group("layout_panels", "add_plugin_scene", plugin_name,
			{scene: _scenes[plugin_name][scene]})
		return

	var loader = get_plugin_loader(plugin_name)
	if not loader:
		return

	loader.plugin_load_scene(scene)


## Should be called when a scene of a plugin is to be removed and should be unloaded from layout.[br]
func remove_scene(plugin_name: String, scene: String):
	if _scenes.has(plugin_name) and _scenes[plugin_name].erase(scene):
		get_tree().call_group("layout_panels", "remove_plugin_scene", plugin_name, scene)


func edit_panel(panel: LayoutPanel):
	get_node("/root/Main/LayoutPopup").show_config(panel.get_plugin_instance().edit_config(),
		panel.panel_name)


func generate_plugins_enum() -> Dictionary:
	var ret_dict: Dictionary = {}
	var i: int = 0
	for plugin in get_activated_plugins():
		ret_dict[plugin] = i
		i += 1

	return ret_dict


func generate_scene_enum(plugin: String) -> Dictionary:
	var ret_dict: Dictionary = {}
	var i: int = 0
	for scene in get_plugin_loader(plugin).scenes:
		ret_dict[scene] = i
		i += 1

	return ret_dict


func add_panel(leaf: DockableLayoutPanel):
	get_node("/root/Main/Layout").set_new_panel_leaf(leaf)
	get_node("/root/Main/LayoutPopup").new_panel()


class Plugin:
	var plugin_name: String

	var _plugin_path: String
	var _activated: bool = false
	var _loader: PluginLoaderBase = null


	func _init(dict: Dictionary, plugin_path: String):
		deserialize(dict)
		_plugin_path = plugin_path


	func is_activated() -> bool:
		return _activated


	func set_activated(activated: bool):
		if activated and not _loader:
			_loader = load("res://plugins/%s/loader.gd" % _plugin_path).new()
			PluginCoordinator.add_child(_loader)
			_loader.plugin_load()
		elif not activated and _loader:
			_loader.plugin_unload()
			_loader.free()
			_loader = null

		_activated = activated


	func get_loader() -> PluginLoaderBase:
		return _loader


	func deserialize(dict: Dictionary):
		plugin_name = dict["plugin_name"]
