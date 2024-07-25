class_name PanelEditor
extends Control

## Config that currently is being edited
var _config_editor: Config.ConfigEditor = null
## Tracks whether a new panel is to be created or an existing one is being edited
var _new_panel: bool = false


func show_panel_config(editor: Config.ConfigEditor):
	if _config_editor:
		_config_editor.queue_free()

	_new_panel = false
	_config_editor = editor
	add_child(_config_editor)


func show_new_panel():
	if _config_editor:
		_config_editor.queue_free()

	_new_panel = true

	# Generate a config and the editor for the new panel
	var new_plugin_config: Config = Config.new([
		{"TYPE": "STRING", "KEY": "Panel Name", "DEFAULT_VALUE": ""},
		{"TYPE": "ENUM", "KEY": "Plugin", "DEFAULT_VALUE": -1, "ENUM": PluginCoordinator.generate_plugins_enum()},
		{"TYPE": "ENUM", "KEY": "Scene", "DEFAULT_VALUE": -1, "ENUM": {}},
	])
	_config_editor = new_plugin_config.generate_editor()

	# Connect the plugin enum editor here, because we need to populate
	# the scene enum with the available scenes from the selected plugin
	var plugins_editor: Config.EnumEditor = _config_editor.get_editor("Plugin")
	plugins_editor.get_value_editor().connect("item_selected", _on_new_panel_plugin_selected)

	add_child(_config_editor)


func save() -> bool:
	if _new_panel:
		return _new_panel_save()
	else:
		_config_editor.apply()
		_config_editor.save()

	return true


func _on_new_panel_plugin_selected(idx: int):
	if idx == -1:
		return

	var scene_editor: Config.EnumEditor = _config_editor.get_editor("Scene")
	var plugins_editor: Config.EnumEditor = _config_editor.get_editor("Plugin")
	scene_editor.set_enum_dict(PluginCoordinator.generate_scene_enum(plugins_editor.get_value_string()))


func _new_panel_save() -> bool:
	var new_panel_dict: Dictionary = _config_editor.serialize()
	var abort: bool = false

	# Give user feedback on what's missing
	if new_panel_dict["Panel Name"] == "":
		_config_editor.get_editor("Panel Name").modulate = Color.RED
		abort = true
	else:
		_config_editor.get_editor("Panel Name").modulate = Color.WHITE

	if new_panel_dict["Plugin"] == -1:
		_config_editor.get_editor("Plugin").modulate = Color.RED
		abort = true
	else:
		_config_editor.get_editor("Plugin").modulate = Color.WHITE

	if new_panel_dict["Scene"] == -1:
		_config_editor.get_editor("Scene").modulate = Color.RED
		abort = true
	else:
		_config_editor.get_editor("Scene").modulate = Color.WHITE

	if abort: return false

	new_panel_dict["UUID"] = UUID.v4()
	new_panel_dict["Scene"] = _config_editor.get_editor("Scene").get_value_string()
	new_panel_dict["Plugin"] = _config_editor.get_editor("Plugin").get_value_string()
	get_node("/root/Main/Layout").add_panel(new_panel_dict)
	return true
