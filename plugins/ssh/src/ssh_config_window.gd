class_name SSHConfigWindow
extends Control

var _ssh_controller: SSHController = PluginCoordinator.get_plugin_loader("SSH").get_controller("SSHController")
var _client_index: int = -1
var _client_config: Config
var _client_editor: Config.ConfigEditor


func _ready() -> void:
	populate_list()


## Edits a client by [param index] from [member SSHController.client_list].
func edit_client(index: int) -> void:
	if _ssh_controller.client_list.size() != index:
		_client_index = index
		_client_config = _ssh_controller.client_list[index]
	else:
		_client_config = _ssh_controller.generate_default_client_config()

	_client_editor = _client_config.generate_editor()
	_client_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var client_delete_button: Button = Button.new()
	client_delete_button.text = "Delete client"
	client_delete_button.pressed.connect(_on_ssh_client_delete_button_pressed)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_child(_client_editor)
	vbox.add_child(client_delete_button)

	PopupManager.push_stack_item(vbox, _on_confirm_client_editor, _on_cancel_client_editor)


## Populates the client list with all current clients from ssh_controller
func populate_list() -> void:
	%SSHClientList.clear()
	for ssh_client in _ssh_controller.client_list:
		%SSHClientList.add_item(ssh_client.get_object("name").get_value())

	%SSHClientList.add_item("+")


## Saves the client that is currently being edited.
func save_client() -> void:
	_client_editor.apply()

	if _client_index == -1:
		_ssh_controller.add_client(_client_config)
	else:
		_ssh_controller.edit_client_config(_client_index)

	populate_list()


## Called by [PopupManager] on confirm button pressed.
func _on_settings_confirmed() -> bool:
	return true


## Called by [PopupManager] on cancel button pressed.
func _on_settings_cancelled() -> void:
	pass


# Called by [PopupManager] on confirm button pressed when editing a client.
func _on_confirm_client_editor() -> bool:
	if _ensure_unique_name(_client_editor.get_editor("name").get_value()):
		save_client()
		_client_index = -1
		return true

	_client_editor.get_editor("name").modulate = Color.RED

	return false


# Called by [PopupManager] on cancel button pressed when editing a client.
func _on_cancel_client_editor() -> void:
	_client_index = -1


# Ensures the name of the currently being edited client is unique if it changed.
func _ensure_unique_name(client_name: String) -> bool:
	var i: int = 0
	for ssh_client in _ssh_controller.client_list:
		if ssh_client.get_object("name").get_value() == client_name and _client_index != i:
			return false

		i += 1

	return true


func _on_ssh_client_list_item_selected(index: int) -> void:
	edit_client(index)


# Delete button for current client was pressed,
# ask for confirmation to make sure deletion is not accidental
func _on_ssh_client_delete_button_pressed() -> void:
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Do you really want to delete this SSH client?"

	# Add as a child of current popup because this ensures it is shown.
	# Other things here may or may not be visible currently.
	PopupManager.get_current_popup().add_child(confirm_dialog)

	confirm_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	confirm_dialog.show()
	confirm_dialog.connect("confirmed", _on_confirm_deletion)


# Finally deletes client and then refreshes and shows the client list again
func _on_confirm_deletion() -> void:
	_ssh_controller.remove_client(_client_config.get_object("name").get_value())
	_ssh_controller.save_clients()

	# Show client list again
	PopupManager.pop_stack_item()

	# Refresh list to not show deleted client anymore
	populate_list()
