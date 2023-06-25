extends Node

var loaded := false


func load(node):
	if OS.get_name() != "X11":
		push_error("SpotifyPanelLegacy only works on linux")
		return
	if not loaded:
		node.get_node("/root/Main/VSeparator/ElementSeparator/SpotifyMargin").add_child(
			load("res://plugins/SpotifyPanelLegacy/scenes/SpotifyPanelLegacy.tscn").instance()
			)
		loaded = true


func unload(node):
	if loaded:
		node.get_node("/root/Main/VSeparator/ElementSeparator/SpotifyMargin/SpotifyPanelLegacy").queue_free()
		loaded = false
