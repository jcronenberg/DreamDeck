extends Control
class_name MainMenu

const plugins_popup_scene = preload("res://src/main_menu/plugins_popup.tscn")

var _settings_popup: Config.ConfigEditor = null

# State
var main_menu_constructed := false


func _ready():
	construct_main_menu()


func construct_main_menu():
	if main_menu_constructed:
		return

	# Settings
	var settings_button: Button = Button.new()
	settings_button.text = "Settings"
	settings_button.theme_type_variation = "MyMenuButton"
	settings_button.custom_minimum_size = Vector2(0, 60)
	settings_button.connect("pressed", _on_settings_button_pressed)
	$Menu/SettingSeparator.add_child(settings_button)
	# Plugins
	var plugins_button: Button = Button.new()
	plugins_button.text = "Plugins"
	plugins_button.theme_type_variation = "MyMenuButton"
	plugins_button.custom_minimum_size = Vector2(0, 60)
	plugins_button.connect("pressed", _on_plugins_button_pressed)
	$Menu/SettingSeparator.add_child(plugins_button)
	# Edit Mode
	var edit_mode_button: Button = Button.new()
	edit_mode_button.text = "Edit Mode"
	edit_mode_button.theme_type_variation = "MyMenuButton"
	edit_mode_button.custom_minimum_size = Vector2(0, 60)
	edit_mode_button.connect("pressed", GlobalSignals.toggle_edit_mode)
	$Menu/SettingSeparator.add_child(edit_mode_button)
	# Quit button
	var quit_button: Button = Button.new()
	quit_button.text = "Quit"
	quit_button.theme_type_variation = "MyMenuButton"
	quit_button.custom_minimum_size = Vector2(0, 60)
	quit_button.connect("pressed", get_tree().quit)
	$Menu/SettingSeparator.add_child(quit_button)

	main_menu_constructed = true


func _on_settings_button_pressed() -> void:
	_settings_popup = ConfigLoader.config.generate_editor()
	PopupManager.init_popup(_settings_popup, _on_settings_confirmed)


func _on_settings_confirmed() -> bool:
	_settings_popup.apply()
	return true


func _on_plugins_button_pressed() -> void:
	var plugins_popup: PluginsPopup = plugins_popup_scene.instantiate()
	PopupManager.init_popup(plugins_popup)
