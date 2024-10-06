class_name SSHConfigWindow
extends Control

const client_configurator_scene = preload("res://plugins/ssh/src/ssh_client_configurator.tscn")

var _ssh_controller: SSHController = PluginCoordinator.get_plugin_loader("SSH").get_controller("SSHController")
var _client_index: int = -1
var _client_configurator: SSHClientConfigurator = null


func _ready():
	populate_list()


func edit_client(index: int):
	var client_dict: Dictionary = {}
	if _ssh_controller.get_client_list().size() != index:
		_client_index = index
		client_dict = _ssh_controller.get_client_list()[index]

	var client_configurator: SSHClientConfigurator = client_configurator_scene.instantiate()
	_client_configurator = client_configurator

	PopupManager.push_stack_item(client_configurator, _on_confirm_client_configurator, _on_cancel_client_configurator)
	client_configurator.edit_ssh_client(client_dict)


func populate_list():
	%SSHClientList.clear()
	for ssh_client in _ssh_controller.get_client_list():
		%SSHClientList.add_item(ssh_client["name"])

	%SSHClientList.add_item("+")


func save_client(client_dict: Dictionary) -> bool:
	if not _ensure_unique_name(client_dict["name"]):
		return false

	if _client_index == -1:
		_ssh_controller.add_new_client(client_dict)
	else:
		_ssh_controller.edit_client_config(_client_index, client_dict)

	return true


func confirm() -> bool:
	return true


func cancel() -> void:
	pass


func _on_confirm_client_configurator() -> bool:
	if save_client(_client_configurator.serialize()):
		populate_list()
		_client_configurator.queue_free()
		_client_configurator = null
		_client_index = -1
		return true

	return false


func _on_cancel_client_configurator() -> void:
	_client_configurator.queue_free()
	_client_configurator = null
	_client_index = -1


func _ensure_unique_name(client_name: String) -> bool:
	var i: int = 0
	for ssh_client in _ssh_controller.get_client_list():
		if ssh_client["name"] == client_name and _client_index != i:
			return false

		i += 1

	return true


func _on_ssh_client_list_item_selected(index: int) -> void:
	edit_client(index)
