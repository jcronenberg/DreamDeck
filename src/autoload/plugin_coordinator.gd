extends Node

signal panels_changed

const DREAMDECK_VERSION := "0.1.0"
const FILENAME := "plugins.json"
const DEFAULT_ACTIVATED_PLUGINS := {
	"Macroboard": true,
}

@export var layout_setup_finished: bool = false:
	set = set_layout_setup_finished

var layout: Layout:
	set(value):
		layout = value
		panels_changed.emit()

var _conf_dir: String = ArgumentParser.get_conf_dir()
var _conf_path: String  # Path for plugins.json
var _plugins: Array[Plugin] = []
# This isn't stored inside _plugins because this the builtin is
# meant to be special in that e.g. it's not possible to be disabled
# and it also shouldn't appear in the plugin dialog
var _builtin_loader: BuiltinLoader
# _scenes example:
# {"Spotify Panel": {"Spotify Panel1": scene, "Spotify Panel2": scene}, "Macroboard": {"Macroboard": scene}}
var _scenes: Dictionary  # The already loaded scenes


func _ready():
	_conf_path = _conf_dir.path_join(FILENAME)

	_builtin_loader = BuiltinLoader.new()
	add_child(_builtin_loader)
	_builtin_loader.plugin_load()

	discover_plugins()
	load_activated_plugins()


# FIXME doesn't check if already there, so can't currently be called at runtime
## Discovers all plugins at `res://plugins` and adds them to [member _plugins].
## It also loads all files in [member _conf_dir]/plugins as resource packs.
func discover_plugins():
	_runtime_load_plugins()

	var discovered_plugins: Array = list_plugins()
	for plugin_path in discovered_plugins:
		var plugin_config: FileAccess = FileAccess.open(
			"res://plugins/%s/plugin.json" % plugin_path, FileAccess.READ
		)
		if not plugin_config:
			push_error("Plugin %s is missing it's plugin.json file" % plugin_path)
			continue

		var plugin_json: Variant = JSON.parse_string(plugin_config.get_as_text())
		if not plugin_json or typeof(plugin_json) != TYPE_DICTIONARY:
			push_error("Failed to parse %s's plugin.json" % plugin_path)
			continue

		_plugins.append(Plugin.new(plugin_json, plugin_path))


func _runtime_load_plugins():
	ConfLib.ensure_dir_exists(_conf_dir.path_join("plugins"))
	var file_list = ConfLib.list_files_in_dir(_conf_dir.path_join("plugins"))
	for file in file_list:
		if not ProjectSettings.load_resource_pack(file):
			push_error("Failed to load plugin %s" % file)


func get_plugins():
	var plugins: Array[Plugin] = []
	for plugin in _plugins:
		if plugin.is_os_allowed():
			plugins.push_back(plugin)
	return plugins


func get_activated_plugins() -> Array[String]:
	var ret_array: Array[String] = ["DreamDeck"]
	for plugin in _plugins:
		if plugin.is_activated():
			ret_array.push_back(plugin.plugin_name)

	return ret_array


func get_plugin_config() -> Dictionary:
	var ret_dict: Dictionary = {}
	for plugin in _plugins:
		ret_dict[plugin.plugin_name] = plugin.is_activated()
	return ret_dict


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
	var cache_dir: String = OS.get_user_data_dir().path_join("cache").path_join(
		plugin_name.to_snake_case()
	)
	ConfLib.ensure_dir_exists(cache_dir)
	return cache_dir


func list_plugins() -> Array:
	var files: Array = []
	var dir: DirAccess = DirAccess.open("res://plugins")
	dir.list_dir_begin()

	while true:
		var file: String = dir.get_next()
		if file == "":
			break
		elif not file.begins_with(".") and not files.has(file):
			files.append(file)

	dir.list_dir_end()

	return files


func get_plugin_path(plugin_name) -> String:
	return _conf_dir.path_join("plugin_configs").path_join(plugin_name)


## Returns loader of [param plugin_name]. Null if plugin doesn't exist or isn't loaded.
func get_plugin_loader(plugin_name: String) -> PluginLoaderBase:
	if plugin_name == "DreamDeck":
		return _builtin_loader
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
		get_tree().call_group(
			"layout_panels", "add_plugin_scene", plugin_name, {scene: _scenes[plugin_name][scene]}
		)
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
	var instance: PluginSceneBase = panel.get_plugin_instance()
	if instance:
		instance.edit_config()


func get_plugin_actions() -> Array[PluginActionDefinition]:
	var actions: Array[PluginActionDefinition] = []
	actions.append_array(_builtin_loader.actions)
	for plugin in _plugins:
		var loader: PluginLoaderBase = plugin.get_loader()
		if loader:
			actions.append_array(loader.actions)
	return actions


func add_panel(leaf: DockableLayoutPanel, source_container: DockableContainer = null) -> void:
	var target: DockableContainer = (
		source_container if source_container else get_node("/root/Main/Layout")
	)
	target.set_new_panel_leaf(leaf)
	var new_panel_editor: NewPanelEditor = NewPanelEditor.new()
	new_panel_editor.target_layout = target
	PopupManager.init_popup([new_panel_editor], new_panel_editor.save)


# Performs a complete re-initialization.
func _reinit() -> void:
	# Remove all plugin loaders
	for plugin in _plugins:
		var loader: PluginLoaderBase = plugin.get_loader()
		if loader:
			loader.queue_free()

	_plugins = []
	_scenes = {}

	# Reinit
	discover_plugins()
	load_activated_plugins()


class Plugin:
	var plugin_name: String
	var plugin_description: String
	var plugin_version: String
	var min_api_version: String

	var _icon_path: String
	var _has_settings: bool = false
	var _allowed_oses: Array = []

	var _plugin_path: String
	var _activated: bool = false
	var _loader: PluginLoaderBase = null

	func _init(dict: Dictionary, plugin_path: String):
		deserialize(dict)
		_plugin_path = plugin_path

	func is_activated() -> bool:
		return _activated

	func is_api_compatible() -> bool:
		if min_api_version.is_empty():
			return true

		var dd_version: PackedStringArray = PluginCoordinator.DREAMDECK_VERSION.split(".")
		var plugin_min: PackedStringArray = min_api_version.split(".")
		if dd_version.size() < 2 or plugin_min.size() < 2:
			return false

		if int(dd_version[0]) != int(plugin_min[0]):
			return false
		return int(dd_version[1]) >= int(plugin_min[1])

	func set_activated(activated: bool):
		if not is_os_allowed():
			return

		if activated and not is_api_compatible():
			push_error(
				(
					"Plugin %s requires min API version %s, but DreamDeck is %s"
					% [plugin_name, min_api_version, PluginCoordinator.DREAMDECK_VERSION]
				)
			)
			return

		if activated and not _loader:
			_loader = load("res://plugins/%s/loader.gd" % _plugin_path).new()
			PluginCoordinator.add_child(_loader)
			_loader.plugin_load()
			GlobalSignals.activated_plugins_changed.emit()
			_has_settings = _loader.has_settings
		elif not activated and _loader:
			_loader.plugin_unload()
			_loader.free()
			_loader = null
			GlobalSignals.activated_plugins_changed.emit()
			_has_settings = false

		_activated = activated

	func get_loader() -> PluginLoaderBase:
		return _loader

	func get_icon() -> Texture2D:
		var icon_path: String
		if _icon_path:
			if ResourceLoader.exists(_icon_path):
				icon_path = _icon_path
			else:
				icon_path = "res://plugins/%s/%s" % [_plugin_path, _icon_path]
		else:
			icon_path = "res://resources/icons/dreamdeck.png"

		return load(icon_path)

	func show_settings_button() -> bool:
		return is_activated() and _has_settings

	func is_os_allowed() -> bool:
		if not _allowed_oses.is_empty() and not _allowed_oses.has(OS.get_name()):
			return false
		return true

	## Function that populates values from a plugin's "plugin.json" file.
	func deserialize(dict: Dictionary):
		plugin_name = dict["plugin_name"]
		if dict.has("description"):
			plugin_description = dict["description"]
		if dict.has("icon_path"):
			_icon_path = dict["icon_path"]
		if dict.has("allow_os"):
			_allowed_oses = dict["allow_os"]
		if dict.has("version"):
			plugin_version = dict["version"]
		if dict.has("min_api_version"):
			min_api_version = dict["min_api_version"]


class PluginActionDefinition:
	var name: String
	var description: String
	var controller: String
	var plugin: String
	var func_name: String
	var args: Config

	func _init(
		_name: String,
		_func_name: String,
		_description: String,
		_args: Config,
		_plugin: String,
		_controller: String
	):
		name = _name
		controller = _controller
		description = _description
		plugin = _plugin
		func_name = _func_name
		args = _args


class PluginActionSelector:
	extends VBoxContainer
	var _plugin_selector: OptionButton = OptionButton.new()
	var _action_selector: OptionButton = OptionButton.new()
	var _description_label: RichTextLabel = RichTextLabel.new()
	var _plugin_actions: Array[PluginActionDefinition] = PluginCoordinator.get_plugin_actions()

	func _init() -> void:
		set_anchors_preset(PRESET_FULL_RECT)
		add_theme_constant_override("separation", 10)

		fill_plugins()
		_plugin_selector.connect("item_selected", _on_plugin_selected)
		_action_selector.connect("item_selected", _on_action_selected)

		var plugin_selector_hbox: HBoxContainer = HBoxContainer.new()
		var plugin_label: Label = Label.new()
		plugin_label.text = "Plugin"
		plugin_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_plugin_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plugin_selector_hbox.add_child(plugin_label)
		plugin_selector_hbox.add_child(_plugin_selector)
		add_child(plugin_selector_hbox)

		var name_selector_hbox: HBoxContainer = HBoxContainer.new()
		var name_label: Label = Label.new()
		name_label.text = "Action"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_action_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_selector_hbox.add_child(name_label)
		name_selector_hbox.add_child(_action_selector)
		add_child(name_selector_hbox)

		var description_name_label: Label = Label.new()
		description_name_label.text = "Description:"
		add_child(description_name_label)
		_description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_description_label.bbcode_enabled = true
		add_child(_description_label)

	func fill_plugins() -> void:
		var plugins: Array[String] = []
		for plugin_action in _plugin_actions:
			if not plugins.has(plugin_action.plugin):
				plugins.append(plugin_action.plugin)

		_plugin_selector.clear()
		for plugin in plugins:
			_plugin_selector.add_item(plugin)

		_plugin_selector.select(-1)

	func get_selected_action() -> PluginActionDefinition:
		if _plugin_selector.get_selected_id() == -1 or _action_selector.get_selected_id() == -1:
			return null

		var selected_plugin: String = _plugin_selector.get_item_text(
			_plugin_selector.get_selected_id()
		)
		var selected_name: String = _action_selector.get_item_text(
			_action_selector.get_selected_id()
		)

		for plugin_action in _plugin_actions:
			if plugin_action.plugin == selected_plugin and plugin_action.name == selected_name:
				return plugin_action

		return null

	func _get_actions_for_plugin(plugin: String) -> Array[String]:
		var actions: Array[String] = []
		for plugin_action in _plugin_actions:
			if plugin_action.plugin == plugin:
				actions.append(plugin_action.name)

		return actions

	func _on_plugin_selected(index: int) -> void:
		var plugin: String = _plugin_selector.get_item_text(index)
		_action_selector.clear()
		for action in _get_actions_for_plugin(plugin):
			_action_selector.add_item(action)

		_on_action_selected()

	func _on_action_selected(_index: int = -1) -> void:
		var action: PluginActionDefinition = get_selected_action()
		if action == null:
			return

		_description_label.text = action.description


class PluginAction:
	var controller: String
	var plugin: String
	var func_name: String
	var args: Array[Variant]:
		set = set_args
	var blocking: bool

	var _call_args: Array[Variant]

	func deserialize(dict: Dictionary) -> void:
		controller = dict["controller"]
		plugin = dict["plugin"]
		func_name = dict["func_name"]
		blocking = dict["blocking"]
		args = dict["args"]

	func serialize() -> Dictionary:
		return {
			"controller": controller,
			"plugin": plugin,
			"func_name": func_name,
			"args": args,
			"blocking": blocking
		}

	func set_args(value: Array[Variant]) -> void:
		args = value

		_call_args = args.duplicate(true)
		_call_args.insert(0, blocking)

	func execute() -> void:
		var loader_instance: PluginLoaderBase = PluginCoordinator.get_plugin_loader(plugin)
		if not loader_instance:
			push_error("Failed to get plugin: %s" % plugin)
			return
		var controller_instance: PluginControllerBase = loader_instance.get_controller(controller)
		if not controller_instance:
			push_error("Failed to get controller '%s' in plugin '%s'" % [controller, plugin])
			return

		var ret: Variant = await controller_instance.callv(func_name, _call_args)
		if typeof(ret) == TYPE_BOOL and not ret:
			push_warning("Action %s %s failed" % [func_name, args])
