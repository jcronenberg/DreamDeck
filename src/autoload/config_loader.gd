extends Node

const DEFAULT_CONFIG := {
	"Transparent Background": false,
	"Fullscreen": false,
	"Hide Mouse Cursor": false,
	"Debug": false,
	"Window Size": {
		"Width": 1280,
		"Height": 800
		},
	}

var conf_dir: String = ArgumentParser.get_conf_dir()
var config: Config = Config.new()


func _ready():
	if OS.has_feature("editor"):
		# So in editor we don't overwrite logs in normal config
		ProjectSettings.set_setting("application/config/use_custom_user_dir", false)

	config.set_config_path(conf_dir + "config.json")
	config.add_bool("Transparent background", "transparent_bg", false)
	config.add_bool("Fullscreen", "fullscreen", false)
	config.add_bool("Hide mouse cursor", "hide_mouse", false)
	config.add_bool("Debug mode", "debug", false)
	config.add_int("Window size width", "window_size_x", 1280)
	config.add_int("Window size height", "window_size_y", 800)

	# Now that path is set if it is changed we can load
	config.load_config()

	_handle_config()

	config.config_changed.connect(_on_config_changed)
	get_window().connect("size_changed", _on_size_changed)


## Returns the global config data
func get_config() -> Dictionary:
	return config.get_as_dict()


# Returns the directory of all configs, since this can be modified with arguments
# the returned path has a "/" at the end
func get_conf_dir() -> String:
	return conf_dir


func _on_size_changed():
	if get_window().mode == Window.MODE_FULLSCREEN:
		return
	config.get_object("window_size_x").set_value(get_window().get_size().x)
	config.get_object("window_size_y").set_value(get_window().get_size().y)
	config.save()


func _handle_config():
	var config_data: Dictionary = config.get_as_dict()
	# Window Settings
	if config_data["fullscreen"]:
		get_window().mode = Window.MODE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED
		get_window().set_size(Vector2(config_data["window_size_x"], config_data["window_size_y"]))

	# Background Settings
	get_window().transparent = true
	get_window().set_transparent_background(config_data["transparent_bg"])

	# Mouse cursor
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if config_data["hide_mouse"] else Input.MOUSE_MODE_VISIBLE


func _on_config_changed():
	config.save()
	_handle_config()
