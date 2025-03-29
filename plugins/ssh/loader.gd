class_name SSHPluginLoader
extends PluginLoaderBase

# Config for execute command action
var _exec_cmd_config: Config = Config.new()


func _init():
	_exec_cmd_config.add_dict("SSH Client", "ssh_client", null, {})
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


func set_client_config(clients: Dictionary) -> void:
	var ssh_client_object: Config.DictObject = _exec_cmd_config.get_object("ssh_client")
	ssh_client_object.set_dict(clients)
	if clients.size() > 0:
		ssh_client_object.set_value(clients.values()[0])


func _on_settings_button_pressed() -> void:
	get_controller("SSHController")._on_settings_button_pressed()
