extends Control

# Constants
const PLUGIN_NAME = "Macroboard"

# Global nodes
onready var config_loader = get_node("/root/ConfigLoader")
onready var global_signals = get_node("/root/GlobalSignals")

# Global vars
var button_min_size: Vector2 = Vector2(150, 150)
var macro_row = load("res://plugins/Macroboard/scenes/MacroRow.tscn")
var app_button = load("res://plugins/Macroboard/scenes/AppButton.tscn")

func _ready():
	load_from_config()
	global_signals.connect("entered_edit_mode", self, "_on_entered_edit_mode")
	global_signals.connect("exited_edit_mode", self, "_on_exited_edit_mode")

func load_from_config():
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
	for row in $RowSeparator.get_children():
		# Don't add a row if it is empty
		if row.get_child_count() <= 0:
			continue

		save_dict["layout"]["row" + str(row_count)] = {}

		var button_count = 0
		for button in row.get_children():
			save_dict["layout"]["row" + str(row_count)]["button" + str(button_count)] = button.save()
			button_count += 1
		row_count += 1

	return save_dict


func add_edit_buttons():
	var edit_button = load("res://plugins/Macroboard/scenes/EditButton.tscn")
	for row in $RowSeparator.get_children():
		row.add_child(edit_button.instance())

	# Add new row to the end, since we want to enable creating a new row
	var new_row = macro_row.instance()
	new_row.add_child(edit_button.instance())
	$RowSeparator.add_child(new_row)


func remove_edit_buttons():
	for row in $RowSeparator.get_children():
		# If row only has one child, that child is a AddButton and we need to remove it
		# Since that also frees its childs we are done with the whole row and can continue
		if row.get_child_count() == 1:
			row.free()
			continue

		var add_button = row.get_child(row.get_child_count() - 1)
		if add_button.name == "AddButton":
			add_button.free()


func _on_entered_edit_mode():
	add_edit_buttons()


func _on_exited_edit_mode():
	# Need to first remove as otherwise we run the risk of trying to save the edit buttons
	remove_edit_buttons()

	config_loader.save_plugin_config(PLUGIN_NAME, save())
