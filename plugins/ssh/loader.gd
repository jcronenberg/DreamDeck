class_name SSHPluginLoader
extends PluginLoaderBase

const SETTINGS_PAGE = preload("res://plugins/ssh/src/ssh_config_window.tscn")

# Config for execute command action
var _exec_cmd_config: Config = Config.new()


func _init():
	_exec_cmd_config.add_string_array("SSH Client", "ssh_client", "", [])
	_exec_cmd_config.add_string("Command", "command", "")
	actions = [
		PluginCoordinator.PluginActionDefinition.new(
			"Execute SSH command",
			"exec_on_client",
			"Execute a command on a SSH client",
			_exec_cmd_config,
			"SSH",
			"SSHController"
		)
	]

	plugin_name = "SSH"
	controllers = {"SSHController": "res://plugins/ssh/src/ssh_controller.gd"}
	has_settings = true


func set_client_config(clients: Array[String]) -> void:
	var ssh_client_object: Config.StringArrayObject = _exec_cmd_config.get_object("ssh_client")
	ssh_client_object.set_string_array(clients)
	if clients.size() > 0:
		ssh_client_object.set_default_value(clients[0])
		ssh_client_object.set_value(clients[0])


func _on_settings_button_pressed() -> void:
	var settings: Control = SETTINGS_PAGE.instantiate()
	PopupManager.push_stack_item([settings], settings._on_settings_confirmed)
