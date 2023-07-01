extends Control

# Constants
const PLUGIN_NAME = "Macroboard"
const BUTTON_GAP = 10

# Global nodes
onready var config_loader = get_node("/root/ConfigLoader")
onready var global_signals = get_node("/root/GlobalSignals")

# Global vars
var button_min_size: Vector2 = Vector2(150, 150) # default size
var macro_row = load("res://plugins/Macroboard/scenes/MacroRow.tscn")
var app_button = load("res://plugins/Macroboard/scenes/AppButton.tscn")

var max_buttons := Vector2(0, 0)

# Configs
onready var plugin_loader := get_node("/root/PluginLoader")
onready var conf_dir = plugin_loader.get_conf_dir(PLUGIN_NAME)
# Page0 hardcoded for now, because we don't support multiple pages yet
onready var layout_config = load("res://scripts/global/Config.gd").new({"Page0": []}, conf_dir + "layout.json")


func _ready():
	load_from_config()
	global_signals.connect("entered_edit_mode", self, "_on_entered_edit_mode")
	global_signals.connect("exited_edit_mode", self, "_on_exited_edit_mode")


# Loads the saved configuration and instances all rows and buttons
func load_from_config():
	var data = config_loader.get_plugin_config(PLUGIN_NAME)

	if not data or data == {}:
		return

	# Load button settings
	button_min_size = Vector2(data["button_settings"]["height"], data["button_settings"]["width"])

	layout_config.load_config()
	var layout = layout_config.get_config()

	# This is just for the transition away from saving the layout in config.json
	# TODO delete in the future
	if layout["Page0"].size() == 0:
		layout["Page0"] = create_array_from_dict(data)
		layout_config.change_config(layout)
		layout_config.save()
		config_loader.save_plugin_config(PLUGIN_NAME, {"button_settings": {"height": button_min_size.x, "width": button_min_size.y}})

	# Load buttons
	# Iterate through rows in layout
	for row in layout["Page0"]:
		# Instance row so we can modify it
		var cur_row = macro_row.instance()

		# Iterate through buttons in row
		for button in row:
			# Instance button so we can modify it
			var new_button = app_button.instance()
			# Apply button settings
			new_button.set_custom_minimum_size(button_min_size)

			edit_button_keys(new_button, button)

			# Add modified button to current row
			cur_row.add_child(new_button)

		# Add row to scene
		$RowSeparator.add_child(cur_row)


# This function is just for the transition away from saving the layout in config.json
# TODO delete in the future
func create_array_from_dict(data) -> Array:
	var button_array := []
	for row in data["layout"].values():
		var row_array := []
		# Iterate through buttons in row
		for button in row.values():
			row_array.append(button)

		button_array.append(row_array)

	return button_array

# Saves plugin config and layout
# Layout is created from existing button layout
func save():
	config_loader.save_plugin_config(PLUGIN_NAME, {"button_settings": {"height": button_min_size.x, "width": button_min_size.y}})
	var button_array := []
	var row_count = 0
	for row in $RowSeparator.get_children():
		# Don't add a row if it is empty
		if row.get_child_count() <= 0:
			continue

		button_array.append([])

		for button in row.get_children():
			button_array[row_count].append(button.save())
		row_count += 1

	layout_config.change_config({"Page0": button_array})
	layout_config.save()


# Adds AddButtons where they are appropriate
# in this case at the end of all existing rows and creates a new row also containing a AddButton
func create_add_buttons():
	var add_button = load("res://plugins/Macroboard/scenes/AddButton.tscn")
	var row_counter: int = 0
	for row in $RowSeparator.get_children():
		row_counter += 1
		if row.get_child_count() >= max_buttons.x:
			continue
		var add_button_instance = add_button.instance()
		row.add_child(add_button_instance)
		add_button_instance.set_custom_minimum_size(button_min_size)
		add_button_instance.row = row_counter - 1

	# Add new row to the end, since we want to enable creating a new row
	if row_counter >= max_buttons.y:
		return
	var new_row = macro_row.instance()
	var add_button_instance = add_button.instance()
	new_row.add_child(add_button_instance)
	add_button_instance.set_custom_minimum_size(button_min_size)
	add_button_instance.row = row_counter
	$RowSeparator.add_child(new_row)


# Removes all AddButtons from this scene
# and removes the last empty row
func remove_add_buttons():
	for row in $RowSeparator.get_children():
		# If row only has one child, that child is a AddButton and we need to remove it
		# Since that also frees its children we are done with the whole row and can continue
		if row.get_child_count() == 1:
			row.free()
			continue

		var add_button = row.get_child(row.get_child_count() - 1)
		if add_button.name == "AddButton":
			add_button.free()


func _on_entered_edit_mode():
	create_add_buttons()


func _on_exited_edit_mode():
	# Need to first remove as otherwise we run the risk of trying to save the edit buttons
	remove_add_buttons()

	save()

	$EditButtonPopup.visible = false


# Function to be called when the AddButton is pressed
func AddButton_pressed(row, pos):
	$EditButtonPopup.show_popup(row, pos, null)


# Adds or edits a button
# row: row in which this button belongs
# pos: position in row this button is supposed to be
# button_dict: dictionary containing all keys that this button is supposed to have
# button: if an existing button is to be edited this should be non null
#         and contain the button's instance
func add_or_edit_button(row, pos, button_dict, button):
	var row_node := $RowSeparator.get_child(row)

	if not button:
		button = app_button.instance()
		# Apply button settings
		button.set_custom_minimum_size(button_min_size)
		row_node.add_child(button)

	# Check for valid pos
	# child_count - 2 because we need to account for the edit button
	# and child_count returns amount of children but pos starts at 0
	if pos > row_node.get_child_count() - 2:
		pos = row_node.get_child_count() - 2

	edit_button_keys(button, button_dict)
	button.apply_change()

	row_node.move_child(button, pos)

	# Remove and readd edit buttons, because either a new row can be created or
	# the existing edit button would violate max_buttons
	remove_add_buttons()
	create_add_buttons()


# Edits all keys of a button instance with given dict values
# button: scene of button that gets edited
# button_dict: dict that contains all key value pairs that need to be set
func edit_button_keys(button, button_dict):
	# Iterate through all values that need to be set in button
	for key in button_dict.keys():
		# Only set attribute if value is set (may be unnecessary)
		if button_dict[key]:
			button.set(key, button_dict[key])


# Function to be called when an existing button is pressed in edit mode
# button: the instance of the button itself calling this function
func edit_button(button):
	var pos_dict = calculate_pos(button)
	$EditButtonPopup.show_popup(pos_dict["row"], pos_dict["pos"], button)


# This calculates the position of a button
# Returns a dict with keys: row and pos
# May need reevaluating in the future as this is a pretty clumsy approach
func calculate_pos(button) -> Dictionary:
	var row: Node = button.get_parent()
	var row_parent: Node = row.get_parent()

	var row_counter := 0
	var pos_counter := 0

	for child in row.get_children():
		if child == button:
			break
		pos_counter += 1

	for child in row_parent.get_children():
		if child == row:
			break
		row_counter += 1

	return {"row": row_counter, "pos": pos_counter}


# This calculates how many rows and buttons per row are possible
# based on current size
func calculate_size() -> Vector2:
	var size = get_size()
	return Vector2(floor((size.x + BUTTON_GAP) / (button_min_size.x + BUTTON_GAP)), floor((size.y + BUTTON_GAP) / (button_min_size.y + BUTTON_GAP)))


func _on_Macroboard_item_rect_changed():
	max_buttons = calculate_size()
