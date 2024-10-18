extends Control
class_name MainMenu

const plugins_popup_scene = preload("res://src/main_menu/plugins_popup.tscn")

var _settings_popup: Config.ConfigEditor = null


func _ready():
	# Settings
	var settings_button: Button = Button.new()
	settings_button.text = "Settings"
	settings_button.theme_type_variation = "MainMenuButton"
	settings_button.custom_minimum_size = Vector2(0, 60)
	settings_button.connect("pressed", _on_settings_button_pressed)
	$Menu/SettingSeparator.add_child(settings_button)
	# Plugins
	var plugins_button: Button = Button.new()
	plugins_button.text = "Plugins"
	plugins_button.theme_type_variation = "MainMenuButton"
	plugins_button.custom_minimum_size = Vector2(0, 60)
	plugins_button.connect("pressed", _on_plugins_button_pressed)
	$Menu/SettingSeparator.add_child(plugins_button)
	# Edit Mode
	var edit_mode_button: Button = Button.new()
	edit_mode_button.text = "Edit Mode"
	edit_mode_button.theme_type_variation = "MainMenuButton"
	edit_mode_button.custom_minimum_size = Vector2(0, 60)
	edit_mode_button.connect("pressed", GlobalSignals.toggle_edit_mode)
	$Menu/SettingSeparator.add_child(edit_mode_button)
	# Quit button
	var quit_button: Button = Button.new()
	quit_button.text = "Quit"
	quit_button.theme_type_variation = "MainMenuButton"
	quit_button.custom_minimum_size = Vector2(0, 60)
	quit_button.connect("pressed", get_tree().quit)
	$Menu/SettingSeparator.add_child(quit_button)


func _on_settings_button_pressed() -> void:
	var settings_vbox: VBoxContainer = VBoxContainer.new()
	settings_vbox.add_theme_constant_override("separation", 10)

	_settings_popup = ConfigLoader.config.generate_editor()
	_settings_popup.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_vbox.add_child(_settings_popup)

	var backup_button: Button = Button.new()
	backup_button.text = "Backup config"
	backup_button.pressed.connect(_on_backup_button_pressed)
	settings_vbox.add_child(backup_button)
	var import_button: Button = Button.new()
	import_button.text = "Import backup"
	import_button.pressed.connect(_on_import_button_pressed)
	settings_vbox.add_child(import_button)

	PopupManager.init_popup(settings_vbox, _on_settings_confirmed)


func _on_settings_confirmed() -> bool:
	_settings_popup.apply()
	return true


func _on_plugins_button_pressed() -> void:
	var plugins_popup: PluginsPopup = plugins_popup_scene.instantiate()
	PopupManager.init_popup(plugins_popup)


func _on_backup_button_pressed() -> void:
	var file_dialog: FileDialog = _create_backup_file_dialog()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.title = "Choose backup file"
	file_dialog.current_file = "backup.zip"
	file_dialog.show()
	file_dialog.file_selected.connect(_on_backup_file_dialog_completed)


func _on_backup_file_dialog_completed(path: String) -> void:
	ConfigLoader._create_config_zip_at(path)


func _on_import_button_pressed() -> void:
	var file_dialog: FileDialog = _create_backup_file_dialog()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = "Select backup"
	file_dialog.show()
	file_dialog.file_selected.connect(_on_import_file_dialog_completed)


func _on_import_file_dialog_completed(path: String) -> void:
	# If FirstTimeLaunch is open there is no config, so no confirmation is required
	if not get_node_or_null("/root/Main/FirstTimeLaunch"):
		var confirm_dialog = ConfirmationDialog.new()
		confirm_dialog.dialog_text = "This will delete the entire current configuration. Are you sure?"
		PopupManager.get_current_popup().add_child(confirm_dialog)
		confirm_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
		confirm_dialog.show()
		confirm_dialog.confirmed.connect(_on_confirm_import.bindv([path]))
	else:
		_on_confirm_import(path)


func _on_confirm_import(path: String) -> void:
	ConfigLoader._remove_config()
	ConfigLoader._unpack_config_backup(path)
	GlobalSignals._perform_complete_reinit()


func _create_backup_file_dialog() -> FileDialog:
	var file_dialog: FileDialog = FileDialog.new()
	file_dialog.use_native_dialog = true
	file_dialog.force_native = true
	file_dialog.filters = ["*.zip;Zip archive", "*;All files"]
	PopupManager.get_current_popup().add_child(file_dialog)
	return file_dialog
