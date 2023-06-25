extends Node

var loaded := false


func load(node):
	if not loaded:
		node.get_node("/root/Main/VSeparator/ElementSeparator/SpotifyMargin").add_child(
			load("res://plugins/SpotifyPanel/scenes/SpotifyPanel.tscn").instance()
			)
		loaded = true


func unload(node):
	if loaded:
		node.get_node("/root/Main/VSeparator/ElementSeparator/SpotifyMargin/SpotifyPanel").queue_free()
		loaded = false
