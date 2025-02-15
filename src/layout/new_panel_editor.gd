class_name NewPanelEditor
extends Control

## Config that currently is being edited
var _config_editor: Config.ConfigEditor


func _init() -> void:
	# Generate a config and the editor for the new panel
	var new_plugin_config: Config = Config.new()
	new_plugin_config.add_string("Panel Name", "panel_name", "")
	new_plugin_config.add_string_array("Plugin", "plugin", "", _generate_plugin_list())
	new_plugin_config.add_string_array("Scene", "scene", "", [])
	_config_editor = new_plugin_config.generate_editor()

	# Connect the plugin enum editor here, because we need to populate
	# the scene enum with the available scenes from the selected plugin
	var plugins_editor: Config.StringArrayEditor = _config_editor.get_editor("plugin")
	plugins_editor.get_value_editor().connect("item_selected", _on_new_panel_plugin_selected)

	add_child(_config_editor)


func save() -> bool:
	var new_panel_dict: Dictionary = _config_editor.serialize()
	var abort: bool = false

	# Give user feedback on what's missing
	if new_panel_dict["panel_name"] == "":
		_config_editor.get_editor("panel_name").modulate = Color.RED
		abort = true
	else:
		_config_editor.get_editor("panel_name").modulate = Color.WHITE

	if new_panel_dict["plugin"] == "":
		_config_editor.get_editor("plugin").modulate = Color.RED
		abort = true
	else:
		_config_editor.get_editor("plugin").modulate = Color.WHITE

	if new_panel_dict["scene"] == "":
		_config_editor.get_editor("scene").modulate = Color.RED
		abort = true
	else:
		_config_editor.get_editor("scene").modulate = Color.WHITE

	if abort:
		return false

	new_panel_dict["UUID"] = UUID.v4()
	new_panel_dict["scene"] = _config_editor.get_editor("scene").get_value()
	new_panel_dict["plugin"] = _config_editor.get_editor("plugin").get_value()
	get_node("/root/Main/Layout").add_panel(new_panel_dict)
	return true


# Generates a list of all plugins that have at least 1 scene
func _generate_plugin_list() -> Array[String]:
	var ret: Array[String] = []
	for plugin in PluginCoordinator.get_activated_plugins():
		if PluginCoordinator.get_plugin_loader(plugin).scenes.size() > 0:
			ret.append(plugin)

	return ret


func _on_new_panel_plugin_selected(idx: int):
	if idx == -1:
		return

	var scene_editor: Config.StringArrayEditor = _config_editor.get_editor("scene")
	var plugins_editor: Config.StringArrayEditor = _config_editor.get_editor("plugin")
	var scenes: Array[String]
	scenes.assign(PluginCoordinator.get_plugin_loader(plugins_editor.get_value()).scenes.keys())
	scene_editor.set_string_array(scenes)
