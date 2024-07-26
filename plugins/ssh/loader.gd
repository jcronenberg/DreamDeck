class_name SSHPluginLoader
extends PluginLoaderBase

func _init():
	plugin_name = "SSH"
	controllers = {"SSHController": "res://plugins/ssh/scripts/ssh_controller.gd"}
