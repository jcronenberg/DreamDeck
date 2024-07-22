class_name SSHPluginLoader
extends PluginLoaderBase

func _init():
	plugin_name = "ssh"
	scripts = {"SSHController": "res://plugins/ssh/scripts/ssh_controller.gd"}


func get_controller():
	if get_child_count() > 0:
		return get_child(0)
