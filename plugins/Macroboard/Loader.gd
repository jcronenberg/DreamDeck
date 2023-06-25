extends Node

var loaded := false


func load(node):
	if not loaded:
		node.get_node("/root/Main/VSeparator/ElementSeparator/MacroMargin").add_child(
			load("res://plugins/Macroboard/scenes/Macroboard.tscn").instance()
			)
		loaded = true


func unload(node):
	if loaded:
		node.get_node("/root/Main/VSeparator/ElementSeparator/MacroMargin/Macroboard").queue_free()
		loaded = false
