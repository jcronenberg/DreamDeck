extends Control

# Nodes
onready var config_loader = get_node("/root/ConfigLoader")


func _ready():
	construct_main_menu(config_loader.get_config_data())


func construct_main_menu(global_config):
	# Load necessary button types
	var submenu_button := load("res://scenes/MainMenu/SubmenuButton.tscn")
	var execute_function_button := load("res://scenes/MainMenu/ExecuteFunctionButton.tscn")

	var new_button

	# Construct global config
	new_button = submenu_button.instance()
	new_button.rect_size.x = 400
	new_button.init("Global Options", global_config)
	$Menu/OptionSeparator.add_child(new_button)
	new_button = execute_function_button.instance()
	new_button.init("Edit Mode", "/root/GlobalSignals", "toggle_edit_mode")
	new_button.rect_size.x = 400
	$Menu/OptionSeparator.add_child(new_button)


func construct_config():
	config_loader.change_config_data($Menu/OptionSeparator.get_child(1).construct_dict())
