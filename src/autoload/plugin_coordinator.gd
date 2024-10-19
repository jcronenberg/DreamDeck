extends Node

const FILENAME := "plugins.json"
const DEFAULT_ACTIVATED_PLUGINS := {
	"Macroboard": true,
}

var _conf_dir: String = ArgumentParser.get_conf_dir()
var _conf_path: String # Path for plugins.json
var _plugins: Array[Plugin] = []
# _scenes example:
# {"Spotify Panel": {"Spotify Panel1": scene, "Spotify Panel2": scene}, "Macroboard": {"Macroboard": scene}}
var _scenes: Dictionary # The already loaded scenes


@export var layout_setup_finished: bool = false:
	set = set_layout_setup_finished


func _ready():
	_conf_path = _conf_dir + FILENAME

	discover_plugins()
	load_activated_plugins()


# FIXME doesn't check if already there, so can't currently be called at runtime
## Discovers all plugins at `res://plugins` and adds them to [member _plugins].
## It also loads all files in [member _conf_dir]/plugins as resource packs.
func discover_plugins():
	# FIXME in current godot load_resource_pack breaks DirAccess
	# Thus runtime plugins don't work with the editor.
	# If you need to test something export a debug build and test
	# with that.
	if not OS.has_feature("editor"):
		_runtime_load_plugins()

	var discovered_plugins: Array = list_plugins()
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


func get_plugins():
	var plugins: Array[Plugin] = []
	for plugin in _plugins:
		if plugin.is_os_allowed():
			plugins.push_back(plugin)
	return plugins


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
	var files: Array = []
	var dir: DirAccess = DirAccess.open("res://plugins")
	dir.list_dir_begin()

	while true:
		var file: String = dir.get_next()
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
	var panel_editor: PanelEditor = PanelEditor.new()
	panel_editor.show_panel_config(panel.get_plugin_instance().edit_config())
	PopupManager.init_popup([panel_editor], panel_editor.save)


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


func get_plugin_actions() -> Array[PluginActionDefinition]:
	var actions: Array[PluginActionDefinition] = []
	for plugin in _plugins:
		var loader: PluginLoaderBase = plugin.get_loader()
		if loader:
			actions.append_array(loader.actions)

	actions.append_array(DreamdeckBuiltinActions.get_actions())

	return actions


func add_panel(leaf: DockableLayoutPanel):
	get_node("/root/Main/Layout").set_new_panel_leaf(leaf)
	var panel_editor: PanelEditor = PanelEditor.new()
	panel_editor.show_new_panel()
	PopupManager.init_popup([panel_editor], panel_editor.save)


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


	func set_activated(activated: bool):
		if not is_os_allowed():
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


class PluginActionDefinition:
	var name: String
	var description: String
	var controller: String
	var plugin: String
	var func_name: String
	var args: Config


	func _init(_name: String, _func_name: String, _description: String, _args: Config, _plugin: String, _controller: String):
		name = _name
		controller = _controller
		description = _description
		plugin = _plugin
		func_name = _func_name
		args = _args


class PluginActionSelector extends VBoxContainer:
	var _plugin_selector: OptionButton = OptionButton.new()
	var _action_selector: OptionButton = OptionButton.new()
	var _description_label: RichTextLabel = RichTextLabel.new()
	var _plugin_actions: Array[PluginActionDefinition] = PluginCoordinator.get_plugin_actions()


	func _init() -> void:
		set_anchors_preset(PRESET_FULL_RECT)
		set("theme_override_constants/separation", 20)

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

		var selected_plugin: String = _plugin_selector.get_item_text(_plugin_selector.get_selected_id())
		var selected_name: String = _action_selector.get_item_text(_action_selector.get_selected_id())

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
	var args: Array[Variant]
	var blocking: bool


	func deserialize(dict: Dictionary) -> void:
		controller = dict["controller"]
		plugin = dict["plugin"]
		func_name = dict["func_name"]
		args = dict["args"]
		blocking = dict["blocking"]


	func serialize() -> Dictionary:
		return {"controller": controller, "plugin": plugin, "func_name": func_name, "args": args, "blocking": blocking}


	func execute() -> void:
		var controller_instance: PluginControllerBase
		if not controller == "" and not plugin == "":
			var loader_instance: PluginLoaderBase = PluginCoordinator.get_plugin_loader(plugin)
			if not loader_instance:
				push_error("Failed to get plugin: %s" % plugin)
				return
			controller_instance = loader_instance.get_controller(controller)
			if not controller_instance:
				push_error("Failed to get controller: %s" % controller)
				return

		var ret: Variant
		if blocking:
			if plugin == "DreamDeck":
				ret = await DreamdeckBuiltinActions.callv(func_name, args)
			else:
				ret = await controller_instance.callv(func_name, args)
		else:
			if plugin == "DreamDeck":
				ret = DreamdeckBuiltinActions.callv(func_name, args)
			else:
				ret = controller_instance.callv(func_name, args)

		if typeof(ret) == TYPE_BOOL:
			if not ret:
				push_warning("Action %s %s failed" % [func_name, args])
