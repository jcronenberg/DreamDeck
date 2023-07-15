extends Node

var loaded := false


func plugin_load():
	if not loaded:
		get_node("/root/Main/VSeparator/ElementSeparator/MacroMargin").add_child(
			load("res://plugins/Macroboard/scenes/Macroboard.tscn").instantiate()
			)
		loaded = true


func plugin_unload():
	if loaded:
		get_node("/root/Main/VSeparator/ElementSeparator/MacroMargin/Macroboard").queue_free()
		loaded = false
