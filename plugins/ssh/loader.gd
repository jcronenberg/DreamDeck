class_name SSHPluginLoader
extends PluginLoaderBase

var _exec_config: Config = Config.new()


func _init():
	_exec_config.add_string_array("SSH Client", "ssh_client", "", [])
	_exec_config.add_string("Command", "command", "")
	actions = [PluginCoordinator.PluginActionDefinition.new("Execute SSH command", "exec_on_client", "Execute a command on a SSH client", _exec_config, "SSH", "SSHController")]

	plugin_name = "SSH"
	controllers = {"SSHController": "res://plugins/ssh/scripts/ssh_controller.gd"}


func set_client_config(clients: Array[String]) -> void:
	_exec_config.get_object("ssh_client").set_string_array(clients)
