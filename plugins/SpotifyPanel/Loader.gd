extends Node

var loaded := false


func load():
	if not loaded:
		get_node("/root/Main/VSeparator/ElementSeparator/SpotifyMargin").add_child(
			load("res://plugins/SpotifyPanel/scenes/SpotifyPanel.tscn").instance()
			)
		loaded = true


func unload():
	if loaded:
		get_node("/root/Main/VSeparator/ElementSeparator/SpotifyMargin/SpotifyPanel").queue_free()
		loaded = false
