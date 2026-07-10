class_name MinimizePluginLoader
extends PluginLoaderBase


func _init() -> void:
	plugin_name = "Minimize"
	controllers = {"MinimizeController": "res://plugins/minimize/src/minimize_controller.gd"}
	has_settings = true
	actions = [
		PluginCoordinator.PluginActionDefinition.new(
			"Minimize",
			"minimize_app",
			"Minimizes the main window and shows a small floating button to restore it",
			Config.new(),
			"Minimize",
			"MinimizeController"
		)
	]


func _on_settings_button_pressed() -> void:
	var controller: MinimizeController = get_controller("MinimizeController")
	if not controller:
		push_error("Minimize: Failed to get controller")
		return

	var config_editor: Config.ConfigEditor = controller.config.generate_editor()
	PopupManager.push_stack_item(
		[config_editor],
		func apply_and_save() -> void:
			config_editor.apply()
			config_editor.save()
	)
