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
	config_editor.name = "Settings"
	var scenes: Array[Control] = [config_editor]

	var quick_bar_wrapper: MarginContainer = null
	if controller.has_quick_bar():
		quick_bar_wrapper = MarginContainer.new()
		quick_bar_wrapper.name = "Quick Action Bar"
		quick_bar_wrapper.custom_minimum_size = Vector2(0, 200)
		controller.get_quick_bar().set_force_edit_mode(true)
		controller.attach_quick_bar(quick_bar_wrapper)
		scenes.append(quick_bar_wrapper)

		# Live-preview the button amount on the embedded quick bar as it's edited,
		# instead of only picking up the change the next time settings are opened.
		var amount_editor: Config.VariantEditor = config_editor.get_editor("quick_bar_amount")
		amount_editor.value_changed.connect(controller.preview_quick_bar_amount)

	PopupManager.push_stack_item(
		scenes,
		func apply_and_save() -> bool:
			config_editor.apply()
			config_editor.save()
			_stop_editing_quick_bar(controller)
			return true,
		func discard() -> void: _stop_editing_quick_bar(controller)
	)


# Detaches the shared quick action bar from the settings popup (so it survives
# PopupManager freeing the popup's own nodes), resyncs it to the (possibly just
# applied) persisted button amount to discard any unsaved live preview, and turns
# off its forced edit affordance, saving its layout in the process.
func _stop_editing_quick_bar(controller: MinimizeController) -> void:
	if not controller.has_quick_bar():
		return

	controller.detach_quick_bar()
	controller.sync_quick_bar_config()
	controller.get_quick_bar().set_force_edit_mode(false)
