extends Control

# Constants
const PLUGIN_NAME = "Macroboard"

# Global nodes
onready var config_loader = get_node("/root/ConfigLoader")

# Global vars
var button_min_size: Vector2 = Vector2(150, 150)

func _ready():
	load_from_config()

func load_from_config():
	var macro_row = load("res://plugins/Macroboard/scenes/MacroRow.tscn")
	var app_button = load("res://plugins/Macroboard/scenes/AppButton.tscn")
	var data = config_loader.get_plugin_config(PLUGIN_NAME)

	# Load button settings
	button_min_size = Vector2(data["button_settings"]["height"], data["button_settings"]["width"])

	# Load buttons
	# Iterate through rows in data
	for row in data["layout"].values():
		# Instance row so we can modify it
		var cur_row = macro_row.instance()

		# Iterate through buttons in row
		for button in row.values():
			# Instance button so we can modify it
			var new_button = app_button.instance()
			# Apply button settings
			new_button.set_custom_minimum_size(button_min_size)

			# Iterate through all values that need to be set in button
			for key in button.keys():
				# Only set attribute if value is set (may be unnecessary)
				if button[key]:
					new_button.set(key, button[key])

			# Add modified button to current row
			cur_row.add_child(new_button)

		# Add row to scene
		$RowSeparator.add_child(cur_row)

func save():
	var save_dict = {
		"layout" : {},
		"button_settings": {"height": button_min_size.x, "width": button_min_size.y}
	}
	var row_count = 0
	for rows in $RowSeparator.get_children():
		save_dict["layout"]["row" + str(row_count)] = {}
		var button_count = 0
		for button in rows.get_children():
			save_dict["layout"]["row" + str(row_count)]["button" + str(button_count)] = button.save()
			button_count += 1
		row_count += 1
	return save_dict
