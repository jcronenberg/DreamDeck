class_name MacroNoButton
extends MacroButtonBase

func toggle_add_button() -> void:
	disabled = not disabled
	$Icon.visible = not $Icon.visible


func set_add_button(value: bool) -> void:
	disabled = value
	$Icon.visible = value


func _on_pressed() -> void:
	open_editor(true)


func _on_popup_confirmed(popup_window: Control) -> void:
	super(popup_window)
	if popup_window is PluginCoordinator.PluginActionSelector:
		return

	_config_editor.apply()
	var config: Dictionary = _config.get_as_dict()
	var actions: Array[PluginCoordinator.PluginAction] = _actions_editor.deserialize()
	var serialized_actions: Array[Dictionary] = []
	for action in actions:
		serialized_actions.append(action.serialize())
	config["actions"] = serialized_actions

	var new_button: MacroActionButton = load("res://plugins/macroboard/src/buttons/macro_action_button.tscn").instantiate()
	new_button.deserialize(config)

	get_macroboard().call_deferred("replace_button", self, new_button)
