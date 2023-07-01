extends Node

var loaded := false


func load():
	if OS.get_name() != "X11":
		push_error("SpotifyPanelLegacy only works on linux")
		return
	if not loaded:
		get_node("/root/Main/VSeparator/ElementSeparator").add_child(
			load("res://plugins/SpotifyPanelLegacy/scenes/SpotifyPanelLegacy.tscn").instance()
			)
		loaded = true


func unload():
	if loaded:
		get_node("/root/Main/VSeparator/ElementSeparator/SpotifyMargin").queue_free()
		loaded = false
