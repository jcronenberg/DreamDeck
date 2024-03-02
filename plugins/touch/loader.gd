class_name TouchPluginLoader
extends PluginLoader

func _init():
	plugin_name = "touch"
	scene = "res://plugins/touch/scenes/touch.tscn"
	parent = "/root/Main/VSeparator/MarginContainer/ControlsSeparator"
	allow_os = ["Linux"]


func add_scene(resource):
	super(resource)
	var parent_instance = get_node(parent)
	parent_instance.get_node("Placeholder").visible = false
	parent_instance.move_child(_instance, 1)


func plugin_unload():
	get_node(parent + "/Placeholder").visible = true
	super()
