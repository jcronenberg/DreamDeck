extends Window

@onready var client_config_stage = $MarginContainer/SSHClientConfigStage
@onready var client_list_stage = $MarginContainer/SSHClientListStage
var ssh_controller = PluginCoordinator.get_plugin_loader("SSH").get_controller("SSHController")


func _ready():
	show_list()


func edit_client(index: int):
	client_config_stage.visible = true
	client_list_stage.visible = false
	%SSHClientConfigStage.edit_ssh_client(index)


func show_list():
	client_config_stage.visible = false
	client_list_stage.visible = true
	populate_list()


func populate_list():
	%SSHClientList.clear()
	for ssh_client in ssh_controller.get_client_list():
		%SSHClientList.add_item(ssh_client["name"])

	%SSHClientList.add_item("+")


func _on_ssh_client_list_item_clicked(index, _at_position, _mouse_button_index):
	edit_client(index)


func _on_close_button_pressed():
	ssh_controller.hide_config()


func _on_close_requested():
	_on_close_button_pressed()
