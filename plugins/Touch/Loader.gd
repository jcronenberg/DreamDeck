extends Node

var loaded := false

onready var parent := get_node("/root/Main/VSeparator/MarginContainer/ControlsSeparator")


func load():
	if not loaded:
		var touch_scene = load("res://plugins/Touch/scenes/Touch.tscn").instance()
		parent.add_child(touch_scene)
		parent.move_child(touch_scene, 1)
		parent.get_node("Placeholder").visible = false
		loaded = true


func unload():
	if loaded:
		parent.get_node("Placeholder").visible = true
		parent.get_node("Touch").queue_free()
		loaded = false
