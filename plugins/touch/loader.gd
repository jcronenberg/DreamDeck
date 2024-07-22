class_name TouchPluginLoader
extends PluginLoaderBase

func _init():
	plugin_name = "touch"
	scenes = {"Touch": "res://plugins/touch/scenes/touch.tscn"}
	scripts = {"TouchController": "res://plugins/touch/scripts/touch_controller.gd"}
	allow_os = ["Linux"]
