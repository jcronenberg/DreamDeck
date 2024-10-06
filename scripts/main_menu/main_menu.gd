extends Control
class_name MainMenu

const plugins_popup_scene = preload("res://src/main_menu/plugins_popup.tscn")

# Submenus
var settings_submenu

# State
var main_menu_constructed := false


func _ready():
	construct_main_menu()


func construct_main_menu():
	if main_menu_constructed:
		return
	# Load necessary button types
	var submenu_button := load("res://scenes/main_menu/submenu_button.tscn")

	var new_button

	# Settings
	new_button = submenu_button.instantiate()
	new_button.size.x = 400
	new_button.init("Settings", ConfigLoader.get_config())
	settings_submenu = new_button
	$Menu/SettingSeparator.add_child(new_button)
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


func edit_settings():
	# Because this may be called before _ready
	if not main_menu_constructed:
		_ready()

	settings_submenu.clear_submenu()
	settings_submenu.add_submenu(ConfigLoader.get_config())


func construct_config():
	var new_config
	# Global config
	new_config = settings_submenu.construct_dict()
	if new_config.hash() != ConfigLoader.get_config().hash():
		ConfigLoader.change_config(settings_submenu.construct_dict())


func _on_plugins_button_pressed() -> void:
	var plugins_popup: PluginsPopup = plugins_popup_scene.instantiate()
	PopupManager.init_popup(plugins_popup, func unused() -> bool: return true, func unused() -> void: pass)
