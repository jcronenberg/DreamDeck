class_name NewPanelEditor
extends Control

## The layout or panel group that will receive the new panel.
var target_layout: Node = null

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
	plugins_editor.set_default_button_disabled(true)
	plugins_editor.get_value_editor().connect("item_selected", _on_new_panel_plugin_selected)
	var scene_editor: Config.StringArrayEditor = _config_editor.get_editor("scene")
	scene_editor.set_default_button_disabled(true)

	add_child(_config_editor)


func save() -> bool:
	var abort: bool = false
	abort = not _config_editor.get_editor("panel_name").validate("") or abort
	abort = not _config_editor.get_editor("plugin").validate("") or abort
	abort = not _config_editor.get_editor("scene").validate("") or abort
	if abort:
		return false

	var new_panel_dict: Dictionary = _config_editor.serialize()
	new_panel_dict["UUID"] = UUID.v4()
	assert(target_layout, "Missing target layout for new panel")
	target_layout.add_panel(new_panel_dict)
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
