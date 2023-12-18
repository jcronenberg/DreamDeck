extends Node

var loaded := false
var controller_node


func plugin_load():
	if not loaded:
		controller_node = load("res://plugins/SSH/scripts/SSHController.gd").new()
		controller_node.name = "SSHController"
		add_child(controller_node)
		loaded = true


func plugin_unload():
	if loaded:
		controller_node.queue_free()
		loaded = false


func get_controller():
	if loaded:
		return controller_node
