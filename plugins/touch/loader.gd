class_name TouchPluginLoader
extends PluginLoaderBase


func _init():
	plugin_name = "Touch"
	scenes = {"Touch": "res://plugins/touch/scenes/touch.tscn"}
	controllers = {"TouchController": "res://plugins/touch/scripts/touch_controller.gd"}
	has_settings = true
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


func _on_settings_button_pressed() -> void:
	var controller: TouchController = get_controller("TouchController")
	if not controller:
		push_error("Touch: Failed to get controller")
		return

	var settings: VBoxContainer = VBoxContainer.new()
	settings.name = "Settings"
	settings.add_theme_constant_override("separation", 10)

	var label: Label = Label.new()
	label.text = "Default Device"
	settings.add_child(label)

	var device_options: OptionButton = OptionButton.new()
	device_options.add_item("None")
	device_options.add_separator()

	var devices: PackedStringArray = controller.get_devices()
	for device in devices:
		device_options.add_item(device)

	var default_device: String = controller.get_default_device()
	if default_device == "":
		device_options.select(0)
	else:
		var index: int = devices.find(default_device)
		if index == -1:
			# Not currently connected; still show it as the configured default.
			device_options.add_item(default_device)
			index = devices.size()
		device_options.select(index + 2)

	settings.add_child(device_options)

	PopupManager.push_stack_item(
		[settings],
		func apply_and_save() -> bool:
			var selected: int = device_options.get_selected()
			var value: String = "" if selected <= 0 else device_options.get_item_text(selected)
			controller.config.get_object("default_device").set_value(value)
			controller.config.save()
			controller.handle_config()
			return true
	)
