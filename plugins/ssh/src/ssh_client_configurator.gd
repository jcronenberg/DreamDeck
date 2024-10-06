class_name SSHClientConfigurator
extends Control

@onready var edit_scenes := {
	"name": $Items/NameSplit/LineEdit,
	"ip": $Items/IpSplit/LineEdit,
	"user": $Items/UserSplit/LineEdit,
	"port": $Items/PortSplit/LineEdit,
	"key_path": $Items/KeyPathSplit/LineEdit,
	}


func edit_ssh_client(client_dict: Dictionary) -> void:
	for field in client_dict:
		edit_scenes[field].text = str(client_dict[field])


func serialize() -> Dictionary:
	var client_dict: Dictionary = {}
	for field in edit_scenes:
		client_dict[field] = edit_scenes[field].text
		#TODO saving stuff

	client_dict["port"] = int(client_dict["port"])
	return client_dict
