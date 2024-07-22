class_name SpotifyPanelPluginLoader
extends PluginLoaderBase

func _init():
	plugin_name = "spotify_panel"
	scenes = {"SpotifyPanel": "res://plugins/spotify_panel/scenes/spotify_panel.tscn"}
	#parent = "/root/Main/VSeparator/ElementSeparator"
