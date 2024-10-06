class_name SSHClientConfigurator
extends Control

@onready var edit_scenes := {
	"name": $Items/NameSplit/LineEdit,
	"ip": $Items/IpSplit/LineEdit,
	"user": $Items/UserSplit/LineEdit,
	"port": $Items/PortSplit/LineEdit,
	"key_path": $Items/KeyPathSplit/LineEdit,
	}

# Bit of a hack, but the confirm and cancel logic should be handled by the parent
var config_window: SSHConfigWindow = null


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


func confirm() -> bool:
	return config_window.confirm()


func cancel() -> void:
	config_window.cancel()
