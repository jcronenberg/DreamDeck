extends Node

var loaded := false

@onready var parent := get_node("/root/Main/VSeparator/MarginContainer/ControlsSeparator")


func plugin_load():
	if OS.get_name() != "Linux":
		push_error("Touch plugin only works on linux")
		return
	if not loaded:
		var touch_scene = load("res://plugins/Touch/scenes/Touch.tscn").instantiate()
		parent.add_child(touch_scene)
		parent.move_child(touch_scene, 1)
		parent.get_node("Placeholder").visible = false
		loaded = true


func plugin_unload():
	if loaded:
		parent.get_node("Placeholder").visible = true
		parent.get_node("Touch").queue_free()
		loaded = false
