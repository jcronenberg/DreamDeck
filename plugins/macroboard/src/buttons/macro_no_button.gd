class_name MacroNoButton
extends MacroButtonBase

## Emitted when this button is supposed to be replaced by the [param new_button].
signal replace_button(caller: MacroNoButton, button_dict: Dictionary)


func _init() -> void:
	super()
	theme_type_variation = "FixedMacroButton"


func toggle_add_button() -> void:
	disabled = not disabled
	$Icon.visible = not $Icon.visible


func set_add_button(value: bool) -> void:
	disabled = value
	$Icon.visible = value


func _on_pressed() -> void:
	open_editor(true)


func _on_popup_confirmed() -> bool:
	_config_editor.apply()
	var config: Dictionary = _config.get_as_dict()
	var actions: Array[PluginCoordinator.PluginAction] = _actions_editor.deserialize()
	var serialized_actions: Array[Dictionary] = []
	for action in actions:
		serialized_actions.append(action.serialize())

	config["actions"] = serialized_actions

	replace_button.emit(self, config)
	return true
