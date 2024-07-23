extends Node

const FILENAME := "plugins.json"
const DEFAULT_ACTIVATED_PLUGINS := {
	"spotify_panel": false,
	"macroboard": true,
}

var conf_dir: String = OS.get_user_data_dir() + "/"
var activated_plugins: SimpleConfig
var plugin_loaders: Dictionary

@export var layout_setup_finished: bool = false:
	set = set_layout_setup_finished


func _ready():
	var new_conf_dir = ArgumentParser.get_arg("confdir")
	if new_conf_dir:
		if not new_conf_dir.ends_with("/"):
			new_conf_dir = new_conf_dir + "/"

		conf_dir = new_conf_dir

	activated_plugins = SimpleConfig.new(DEFAULT_ACTIVATED_PLUGINS, conf_dir + FILENAME)

	discover_plugins()

	activated_plugins.load_config()

	handle_activated_plugins()


func discover_plugins():
	_runtime_load_plugins()

	var discovered_plugins := list_plugins()
	var new_activated_plugins: Dictionary = activated_plugins.get_config()
	for plugin in discovered_plugins:
		# If plugin already exists it would get overwritten, so we need to skip it
		if not plugin in new_activated_plugins.keys():
			new_activated_plugins[plugin] = false

	activated_plugins.change_config(new_activated_plugins)


func _runtime_load_plugins():
	ConfLib.ensure_dir_exists(conf_dir + "plugins")
	var file_list = ConfLib.list_files_in_dir(conf_dir + "plugins")
	for file in file_list:
		if not ProjectSettings.load_resource_pack(file):
			push_error("Failed to load plugin %s" % file)


func get_activated_plugins() -> Array:
	var ret_array: Array = []
	var activated_plugins_array = activated_plugins.get_config()
	for item in activated_plugins_array:
		if activated_plugins_array[item]:
			ret_array.push_back(item)

	return ret_array


func get_plugin_config() -> Dictionary:
	return activated_plugins.get_config()


func change_activated_plugins(new_data):
	activated_plugins.change_config(new_data)
	activated_plugins.save()

	handle_activated_plugins()
	get_tree().call_group("layout_panels", "load_scene")


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


func get_conf_dir(plugin_name: String) -> String:
	# TODO should probably move this to a separate place
	if plugin_name == "":
		return conf_dir

	ConfLib.ensure_dir_exists(plugin_path(plugin_name))
	return plugin_path(plugin_name)


func get_cache_dir(plugin_name: String):
	ConfLib.ensure_dir_exists(conf_dir + "cache/" + plugin_name + "/")
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
	return conf_dir + "plugin_configs/" + plugin_name + "/"


## Returns loader of [param plugin_name]. Null if plugin doesn't exist or isn't loaded.
func get_plugin_loader(plugin_name: String) -> PluginLoaderBase:
	var activated_plugins_data: Dictionary = activated_plugins.get_config()
	if not plugin_name in activated_plugins_data or not activated_plugins_data[plugin_name]:
		return null

	return plugin_loaders[plugin_name]


func set_layout_setup_finished(value: bool):
	layout_setup_finished = value
	# TODO handle already loaded plugins


# The loaded scenes
# e.g. {"SpotifyPanel": {"SpotifyPanel1": scene, "SpotifyPanel2": scene}, "Macroboard": {"Macroboard": scene}}
var _scenes: Dictionary

## Should be called when a scene of a plugin has loaded and should now be added to the layout.[br]
## [param scene_dict] should be: [code]{scene_name: resource}[/code][br]
func add_scene(plugin_name: String, scene_dict: Dictionary):
	# Store scene
	if _scenes.has(plugin_name):
		_scenes[plugin_name].merge(scene_dict, true)
	else:
		_scenes[plugin_name] = scene_dict

	# If layout setup isn't yet finished, move to later (TODO)
	if not layout_setup_finished:
		return

	# Add scene to layout
	get_tree().call_group("layout_panels", "add_plugin_scene", plugin_name, scene_dict)


## Loads a plugin scene.
# Tries to use cached resources in [member _scenes].
func load_plugin_scene(plugin_name: String, scene: String):
	# If cached in _scenes directly use it
	if _scenes.has(plugin_name) and _scenes[plugin_name].has(scene):
		get_tree().call_group("layout_panels", "add_plugin_scene", plugin_name, {scene: _scenes[plugin_name][scene]})
		# FIXME remove debug
		print("used cached")
		print(scene)
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
	get_node("/root/Main/LayoutPopup").show_config(panel.get_plugin_instance().edit_config(), panel.panel_name)


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
