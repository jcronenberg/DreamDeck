extends Node

var loaded := false


func load():
	if not loaded:
		get_node("/root/Main/VSeparator/ElementSeparator/MacroMargin").add_child(
			load("res://plugins/Macroboard/scenes/Macroboard.tscn").instance()
			)
		loaded = true


func unload():
	if loaded:
		get_node("/root/Main/VSeparator/ElementSeparator/MacroMargin/Macroboard").queue_free()
		loaded = false
