extends Control

# Nodes
@onready var config_loader = get_node("/root/ConfigLoader")
@onready var plugin_coordinator = get_node("/root/PluginCoordinator")

# Submenus
var settings_submenu
var plugins_submenu
var plugin_settings_submenu
var edit_mode_button

# State
var main_menu_constructed := false


func _ready():
	construct_main_menu()


func construct_main_menu():
	if main_menu_constructed:
		return
	# Load necessary button types
	var submenu_button := load("res://scenes/main_menu/submenu_button.tscn")
	var execute_function_button := load("res://scenes/main_menu/execute_function_button.tscn")

	var new_button

	# Settings
	new_button = submenu_button.instantiate()
	new_button.size.x = 400
	new_button.init("Settings", config_loader.get_config())
	settings_submenu = new_button
	$Menu/SettingSeparator.add_child(new_button)
	# Plugins
	new_button = submenu_button.instantiate()
	new_button.size.x = 400
	new_button.init("Plugins", plugin_coordinator.get_activated_plugins())
	plugins_submenu = new_button
	$Menu/SettingSeparator.add_child(new_button)
	# Plugin settings
	new_button = submenu_button.instantiate()
	new_button.size.x = 400
	new_button.init("Plugin settings", plugin_coordinator.get_all_plugin_configs())
	plugin_settings_submenu = new_button
	$Menu/SettingSeparator.add_child(new_button)
	# Edit Mode
	new_button = execute_function_button.instantiate()
	new_button.init("Edit Mode", "/root/GlobalSignals", "toggle_edit_mode")
	new_button.size.x = 400
	edit_mode_button = new_button
	$Menu/SettingSeparator.add_child(new_button)

	main_menu_constructed = true


func edit_plugin_settings():
	# Because this may be called before _ready
	if not main_menu_constructed:
		_ready()

	plugin_settings_submenu.clear_submenu()
	plugin_settings_submenu.add_submenu(plugin_coordinator.get_all_plugin_configs())


func edit_settings():
	# Because this may be called before _ready
	if not main_menu_constructed:
		_ready()

	settings_submenu.clear_submenu()
	settings_submenu.add_submenu(config_loader.get_config())


func construct_config():
	var new_config
	# Global config
	new_config = settings_submenu.construct_dict()
	if new_config.hash() != config_loader.get_config().hash():
		config_loader.change_config(settings_submenu.construct_dict())

	new_config = plugins_submenu.construct_dict()
	if new_config.hash() != plugin_coordinator.get_activated_plugins().hash():
		plugin_coordinator.change_activated_plugins(plugins_submenu.construct_dict())

	new_config = plugin_settings_submenu.construct_dict()
	if new_config.hash() != plugin_coordinator.get_all_plugin_configs().hash():
		plugin_coordinator.change_all_plugin_configs(plugin_settings_submenu.construct_dict())


## Adds a custom button to the MainMenu
## The button needs to be freed by the caller when it is no longer needed
func add_custom_button(button_scene):
	# Because this may be called before _ready
	if not main_menu_constructed:
		_ready()

	$Menu/SettingSeparator.add_child(button_scene)
