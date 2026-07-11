class_name TouchPluginLoader
extends PluginLoaderBase


func _init():
	plugin_name = "Touch"
	scenes = {"Touch": "res://plugins/touch/scenes/touch.tscn"}
	controllers = {"TouchController": "res://plugins/touch/scripts/touch_controller.gd"}
	actions = [
		PluginCoordinator.PluginActionDefinition.new(
			"Toggle device grab",
			"toggle_grab_device",
			"Toggles whether the current touch device is grabbed",
			Config.new(),
			"Touch",
			"TouchController"
		)
	]
