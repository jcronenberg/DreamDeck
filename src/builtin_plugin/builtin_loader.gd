## The plugin loader for the builtin plugin
class_name BuiltinLoader
extends PluginLoaderBase

var _switch_panel_config: Config = Config.new()


func _init() -> void:
	plugin_name = "DreamDeck"
	scenes = {
		"Panel Group": "res://src/builtin_plugin/panel_group/panel_group.tscn",
	}


func plugin_load() -> void:
	var controller: BuiltinController = BuiltinController.new()
	add_child(controller)
	controller.init()
	_controllers[""] = controller
	_setup_actions()
	PluginCoordinator.panels_changed.connect(_on_panels_changed)


func _on_panels_changed() -> void:
	if not PluginCoordinator.layout:
		return

	var panels: Array[String] = PluginCoordinator.layout.get_panel_names()
	var panel_object: Config.StringArrayObject = _switch_panel_config.get_object("panel_name")
	if panel_object:
		panel_object.set_string_array(panels)
		if panels.size() > 0:
			panel_object.set_default_value(panels[0])
			panel_object.set_value(panels[0])


func _setup_actions() -> void:
	var exec_cmd_config: Config = Config.new()
	exec_cmd_config.add_string("Command", "command", "")
	var timer_config: Config = Config.new()
	timer_config.add_float("Time", "time", 1.0)
	_switch_panel_config.add_string_array("Panel name", "panel_name", "", [])

	actions = [
		PluginCoordinator.PluginActionDefinition.new(
			"Execute command",
			"exec_cmd",
			"Execute a command on this device",
			exec_cmd_config,
			"DreamDeck",
			""
		),
		PluginCoordinator.PluginActionDefinition.new(
			"Timer",
			"wait_time",
			"Delays the execution of the next action by configured time in seconds",
			timer_config,
			"DreamDeck",
			""
		),
		PluginCoordinator.PluginActionDefinition.new(
			"Switch panel",
			"switch_panel",
			"Show the panel with the configured name",
			_switch_panel_config,
			"DreamDeck",
			""
		),
	]
