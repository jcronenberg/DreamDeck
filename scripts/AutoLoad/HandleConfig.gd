extends Node


onready var config_loader = get_node("/root/ConfigLoader")


func _ready():
	handle_config()
	get_node("/root/GlobalSignals").connect("global_config_changed", self, "_on_global_config_changed")


func _on_global_config_changed():
	handle_config()


func handle_config():
	var config_data = config_loader.get_config()
	apply_settings(config_data)


func apply_settings(config_data):
	# Window Settings
	if config_data["Fullscreen"]:
		OS.set_window_fullscreen(true)
	else:
		OS.set_window_fullscreen(false)
		OS.set_window_size(Vector2(config_data["Window Size"]["Width"], config_data["Window Size"]["Height"]))

	# Background Settings
	OS.set_window_per_pixel_transparency_enabled(true)
	get_tree().get_root().transparent_bg = config_data["Transparent Background"]
