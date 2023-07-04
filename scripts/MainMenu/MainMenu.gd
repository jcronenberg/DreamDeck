extends Control

# Nodes
onready var config_loader = get_node("/root/ConfigLoader")
onready var plugin_loader = get_node("/root/PluginLoader")

# Submenus
var settings_submenu
var plugins_submenu
var plugin_settings_submenu
var edit_mode_button


func _ready():
	construct_main_menu()


func construct_main_menu():
	# Load necessary button types
	var submenu_button := load("res://scenes/MainMenu/SubmenuButton.tscn")
	var execute_function_button := load("res://scenes/MainMenu/ExecuteFunctionButton.tscn")

	var new_button

	# Settings
	new_button = submenu_button.instance()
	new_button.rect_size.x = 400
	new_button.init("Settings", config_loader.get_config())
	settings_submenu = new_button
	$Menu/SettingSeparator.add_child(new_button)
	# Plugins
	new_button = submenu_button.instance()
	new_button.rect_size.x = 400
	new_button.init("Plugins", plugin_loader.get_activated_plugins())
	plugins_submenu = new_button
	$Menu/SettingSeparator.add_child(new_button)
	# Plugin settings
	new_button = submenu_button.instance()
	new_button.rect_size.x = 400
	new_button.init("Plugin settings", plugin_loader.get_all_plugin_configs())
	plugin_settings_submenu = new_button
	$Menu/SettingSeparator.add_child(new_button)
	# Edit Mode
	new_button = execute_function_button.instance()
	new_button.init("Edit Mode", "/root/GlobalSignals", "toggle_edit_mode")
	new_button.rect_size.x = 400
	edit_mode_button = new_button
	$Menu/SettingSeparator.add_child(new_button)


func edit_plugin_settings():
	plugin_settings_submenu.clear_submenu()
	plugin_settings_submenu.add_submenu(plugin_loader.get_all_plugin_configs())


func construct_config():
	var new_config
	# Global config
	new_config = settings_submenu.construct_dict()
	if new_config.hash() != config_loader.get_config().hash():
		config_loader.change_config(settings_submenu.construct_dict())

	new_config = plugins_submenu.construct_dict()
	if new_config.hash() != plugin_loader.get_activated_plugins().hash():
		plugin_loader.change_activated_plugins(plugins_submenu.construct_dict())

	new_config = plugin_settings_submenu.construct_dict()
	if new_config.hash() != plugin_loader.get_all_plugin_configs().hash():
		plugin_loader.change_all_plugin_configs(plugin_settings_submenu.construct_dict())
