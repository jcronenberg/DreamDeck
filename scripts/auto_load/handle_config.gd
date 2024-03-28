extends Node


func _ready():
	handle_config()
	GlobalSignals.connect("global_config_changed", Callable(self, "_on_global_config_changed"))
	get_window().connect("size_changed", Callable(self, "_on_size_changed"))


func _on_global_config_changed():
	handle_config()


func _on_size_changed():
	if get_window().mode == Window.MODE_FULLSCREEN:
		return
	var config_data = ConfigLoader.get_config()
	config_data["Window Size"]["Width"] = get_window().get_size().x
	config_data["Window Size"]["Height"] = get_window().get_size().y
	ConfigLoader.save_config()


func handle_config():
	var config_data = ConfigLoader.get_config()
	apply_settings(config_data)


func apply_settings(config_data):
	# Window Settings
	if config_data["Fullscreen"]:
		get_window().mode = Window.MODE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED
		get_window().set_size(Vector2(config_data["Window Size"]["Width"], config_data["Window Size"]["Height"]))

	# Background Settings
	get_window().transparent = true
	get_window().set_transparent_background(config_data["Transparent Background"])

	# Mouse cursor
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if config_data["Hide Mouse Cursor"] else Input.MOUSE_MODE_VISIBLE
