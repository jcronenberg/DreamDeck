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

	load_config()

	config.config_changed.connect(_on_config_changed)
	get_window().connect("size_changed", _on_size_changed)


## Loads [member config] from disk and applies it.
func load_config() -> void:
	config.load_config()
	_handle_config()


## Returns the global config data
func get_config() -> Dictionary:
	return config.get_as_dict()


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


# Creates a zip archive at [param path] of the complete [member conf_dir].
func _create_config_zip_at(path: String) -> void:
	var writer: ZIPPacker = ZIPPacker.new()
	var err: Error = writer.open(path)
	if err != OK:
		push_error("Failed to open backup file %s: %s" % [path, err])
		return

	var files: Array = ConfLib.list_files_in_dir(conf_dir)
	for file in files:
		writer.start_file(file.trim_prefix(conf_dir))
		writer.write_file(FileAccess.get_file_as_bytes(file))
		var error: Error = FileAccess.get_open_error()
		if error != OK:
			push_error("Error when opening file %s: %s" % [file, error])
		writer.close_file()

	writer.close()


# Unpacks a config backup located at [param path] into the [member conf_dir].
func _unpack_config_backup(path: String) -> void:
	var reader: ZIPReader = ZIPReader.new()
	var err: Error = reader.open(path)
	if err != OK:
		push_error("Failed to open backup file %s: %s" % [path, err])
		return

	var files: PackedStringArray = reader.get_files()
	for file in files:
		ConfLib.ensure_dir_exists((conf_dir + file).get_base_dir())

		var writer: FileAccess = FileAccess.open(conf_dir + file, FileAccess.WRITE)
		if not writer:
			push_error("Failed to write to file %s: %s" % [conf_dir + file, FileAccess.get_open_error()])
			continue

		writer.store_buffer(reader.read_file(file))

	reader.close()


# Completely removes everything inside the [member conf_dir].
func _remove_config() -> void:
	var dir: DirAccess = DirAccess.open(conf_dir)

	for file in ConfLib.list_files_in_dir(conf_dir):
		dir.remove(file.trim_prefix(conf_dir))

	for delete_dir in ConfLib.list_dirs_in_dir(conf_dir):
		dir.remove(delete_dir.trim_prefix(conf_dir))
