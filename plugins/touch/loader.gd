class_name TouchPluginLoader
extends PluginLoader

# TODO fix, currently doesn't work
func _init():
	plugin_name = "touch"
	scenes = {"Touch": "res://plugins/touch/scenes/touch.tscn"}
	allow_os = ["Linux"]
