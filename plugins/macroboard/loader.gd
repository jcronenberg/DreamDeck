class_name MacroboardPluginLoader
extends PluginLoaderBase

func _init():
	plugin_name = "Macroboard"
	scenes = {"Macroboard": "res://plugins/macroboard/src/macroboard/macroboard.tscn"}
	controllers = {"MacroboardController": "res://plugins/macroboard/src/controller/controller.gd"}
	has_settings = true


func get_settings_page() -> Control:
	var controller: MacroboardController = get_controller("MacroboardController")
	if not controller:
		push_error("Macroboard: Failed to get controller")
		return null

	return controller.config.generate_editor()
