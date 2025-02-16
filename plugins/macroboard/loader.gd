class_name MacroboardPluginLoader
extends PluginLoaderBase


func _init():
	plugin_name = "Macroboard"
	scenes = {"Macroboard": "res://plugins/macroboard/src/macroboard/macroboard.tscn"}
	controllers = {"MacroboardController": "res://plugins/macroboard/src/controller/controller.gd"}
	has_settings = true


func _on_settings_button_pressed() -> void:
	var controller: MacroboardController = get_controller("MacroboardController")
	if not controller:
		push_error("Macroboard: Failed to get controller")
		return

	var config_editor: Config.ConfigEditor = controller.config.generate_editor()
	PopupManager.push_stack_item(
		[config_editor],
		func apply_and_save() -> void:
			config_editor.apply()
			config_editor.save()
	)
