class_name SSHLoader
extends PluginLoader

func _init():
	plugin_name = "ssh"
	scene = "res://plugins/ssh/scripts/ssh_controller.gd"

# var loaded := false
# var controller_node


# func plugin_load():
# 	if not loaded:
# 		controller_node = load("res://plugins/ssh/scripts/ssh_controller.gd").new()
# 		controller_node.name = "SSHController"
# 		add_child(controller_node)
# 		loaded = true


# func plugin_unload():
# 	if loaded:
# 		controller_node.queue_free()
# 		loaded = false


func get_controller():
	if _loaded:
		return _instance
