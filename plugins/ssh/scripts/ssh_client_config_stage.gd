extends Control

var initial_name: String = ""
var client_index: int = 0
var ssh_controller = PluginCoordinator.get_plugin_loader("SSH").get_controller("SSHController")

@onready var edit_scenes := {
	"name": $Items/NameSplit/LineEdit,
	"ip": $Items/IpSplit/LineEdit,
	"user": $Items/UserSplit/LineEdit,
	"port": $Items/PortSplit/LineEdit,
	"key_path": $Items/KeyPathSplit/LineEdit,
	}

func edit_ssh_client(index: int):
	client_index = index
	if ssh_controller.get_client_list().size() == index:
		return
	var client_dict: Dictionary = ssh_controller.get_client_list()[index]
	initial_name = client_dict["name"]
	for field in client_dict:
		edit_scenes[field].text = str(client_dict[field])


func save():
	if not ensure_unique_name():
		push_error("SSHClient name is not unique")
		return
	var client_dict := {}
	for field in edit_scenes:
		client_dict[field] = edit_scenes[field].text
		#TODO saving stuff

	client_dict["port"] = int(client_dict["port"])
	if initial_name.is_empty():
		ssh_controller.add_new_client(client_dict)
	else:
		ssh_controller.edit_client_config(client_index, client_dict)


func _on_save_button_pressed():
	save()
	get_node("../..").show_list()
	reset_prompt()


func _on_cancel_button_pressed():
	get_node("../..").show_list()
	reset_prompt()


func reset_prompt():
	initial_name = ""
	client_index = 0
	for field in edit_scenes:
		edit_scenes[field].clear()


func ensure_unique_name() -> bool:
	var client_name: String = edit_scenes["name"].text
	if initial_name == client_name:
		return true
	for ssh_client in ssh_controller.get_client_list():
		if ssh_client["name"] == client_name:
			return false

	return true
