class_name SSHPluginLoader
extends PluginLoader

func _init():
	plugin_name = "ssh"
	scene = "res://plugins/ssh/scripts/ssh_controller.gd"


func get_controller():
	if _loaded:
		return _instance
