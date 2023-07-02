extends Control

# Constants
const PLUGIN_NAME = "Macroboard"
const BUTTON_GAP = 10

# Global nodes
onready var global_signals = get_node("/root/GlobalSignals")

# Global vars
var button_min_size: Vector2 = Vector2(150, 150) # default size
var macro_row = load("res://plugins/Macroboard/scenes/MacroRow.tscn")
var app_button = load("res://plugins/Macroboard/scenes/AppButton.tscn")
var no_button = load("res://plugins/Macroboard/scenes/NoButton.tscn")

# The maximum amount of buttons we can currently display
var max_buttons := Vector2(0, 0)

# Configs
onready var plugin_loader := get_node("/root/PluginLoader")
onready var conf_dir = plugin_loader.get_conf_dir(PLUGIN_NAME)
# Page0 hardcoded for now, because we don't support multiple pages yet
onready var layout_config = load("res://scripts/global/Config.gd").new({"Page0": []}, conf_dir + "layout.json")
const DEFAULT_CONFIG := {
	"button_settings": {
		"height": 150,
		"width": 150
	}
}

# To prevent reloading a bunch of times at startup
var initializing = true


func _ready():
	global_signals.connect("entered_edit_mode", self, "_on_entered_edit_mode")
	global_signals.connect("exited_edit_mode", self, "_on_exited_edit_mode")
	global_signals.connect("config_changed", self, "_on_config_changed")


func _on_config_changed():
	load_config()
	_on_size_changed()


# FIXME This is a hack, because on startup the window gets resized a lot
# so we need to wait for it all to settle and then we can handle adding buttons
# this leads to way faster startup times
# But this may also lead to problems in the future so look here if something is acting strange
func _process(_delta):
	load_config()
	layout_config.load_config()
	_on_size_changed()
	load_buttons()
	initializing = false
	set_process(false)


# Loads the saved configuration
func load_config():
	var data = plugin_loader.get_plugin_config(PLUGIN_NAME, DEFAULT_CONFIG)

	if not data or data == {}:
		return

	# Load button settings
	button_min_size = Vector2(data["button_settings"]["height"], data["button_settings"]["width"])

	# This is just for the transition away from saving the layout in config.json
	# TODO delete in the future
	if "layout" in data.keys():
		layout_config.load_config()
		var layout = layout_config.get_config()
		layout["Page0"] = create_array_from_dict(data)
		layout_config.change_config(layout)
		layout_config.save()
		plugin_loader.save_plugin_config(PLUGIN_NAME, {"button_settings": {"height": button_min_size.x, "width": button_min_size.y}})


func free_rows():
	for row in $RowSeparator.get_children():
		row.queue_free()


func load_buttons():
	# For now we just completely rebuild the layout when size is changed
	# TODO maybe improve this
	free_rows()

	var layout = layout_config.get_config()

	for row in max_buttons.y:
		var cur_row = macro_row.instance()

		for button in max_buttons.x:
			var new_button

			# Only if an entry exists at this position we add it
			if layout["Page0"].size() > row and layout["Page0"][row].size() > button and layout["Page0"][row][button]:
				new_button = app_button.instance()
				edit_button_keys(new_button, layout["Page0"][row][button])
			else:
				new_button = no_button.instance()
				new_button.init(row, button)

			new_button.set_custom_minimum_size(button_min_size)

			cur_row.add_child(new_button)


		$RowSeparator.add_child(cur_row)


	# Since all buttons get reset, we need to account for edit mode
	if global_signals.get_edit_state():
		toggle_add_buttons()


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


# Removes original_button and replaces it with new_button
func replace_button(original_button, new_button):
	var row = original_button.get_parent()
	var pos = original_button.get_index()

	row.add_child(new_button)
	row.move_child(new_button, pos)

	original_button.queue_free()


# Swaps button position inside row (Note: probably only works for same row right now)
# TODO allow swapping between different rows
func swap_buttons(button1, button2):
	var button1_row = button1.get_parent()
	var button1_pos = button1.get_index()
	var button2_row = button2.get_parent()
	var button2_pos = button2.get_index()

	# Need to account for the fact that the buttons get removed
	if button1_pos > button2_pos: button1_pos -= 1

	button1_row.remove_child(button1)
	button2_row.remove_child(button2)

	button1_row.add_child(button2)
	button1_row.move_child(button2, button1_pos)
	button2_row.add_child(button1)
	button2_row.move_child(button1, button2_pos)


# "Deletes" a button by replacing it with a no_button instance
func delete_button(button):
	var new_no_button = no_button.instance()
	var button_pos = calculate_pos(button)
	new_no_button.init(button_pos[0], button_pos[1])
	replace_button(button, new_no_button)

	# Because we are guaranteed currently in edit mode
	new_no_button.toggle_add_button()


# Creates the layout array from the existing nodes inside the macroboard
func create_layout_array() -> Array:
	var button_array := []
	var row_count := 0
	for row in $RowSeparator.get_children():
		# Don't add a row if it is empty
		if row.get_child_count() <= 0:
			continue

		button_array.append([])

		for button in row.get_children():
			if button.has_method("save"):
				button_array[row_count].append(button.save())
			else:
				button_array[row_count].append(null)

		row_count += 1

	return button_array


# Since the save function will create arrays containing large amounts of unnecessary nulls
# This function checks if a null really indicates a necessary empty position
# and deletes unnecessary nulls
# E.g. if [button, null, button] the null is required to indicate an empty space
# but for [button, null, button, null] the last null isn't required
func clear_appended_nulls(array: Array):
	var last_not_null_row := -1
	var last_not_null := -1
	for i in array.size():
		for j in array[i].size():
			if array[i][j]:
				last_not_null = j
				last_not_null_row = i
		array[i].resize(last_not_null + 1)
		last_not_null = -1

	array.resize(last_not_null_row + 1)


# This is a special merge for 2 arrays
# It only overwrites entries in original_array if there is something
# at that place in new_array
# This is so we don't overwrite/clear existing buttons only because
# they aren't currently displayed e.g. because of current window size
func merge_layout_array(original_array: Array, new_array: Array):
	for i in new_array.size():
		if i >= original_array.size():
			original_array.append(new_array[i])
		else:
			for j in new_array[i].size():
				if j >= original_array[i].size():
					original_array[i].append(new_array[i][j])
				else:
					original_array[i][j] = new_array[i][j]


# Saves plugin config and layout
# Layout is created from existing button layout
func save():
	plugin_loader.save_plugin_config(PLUGIN_NAME, {"button_settings": {"height": button_min_size.x, "width": button_min_size.y}})

	var layout = layout_config.get_config()
	merge_layout_array(layout["Page0"], create_layout_array())
	clear_appended_nulls(layout["Page0"])

	layout_config.change_config(layout)
	layout_config.save()


# Toggles visibility of empty buttons to allow adding buttons in empty spaces
func toggle_add_buttons():
	for row in $RowSeparator.get_children():
		for button in row.get_children():
			if button.has_method("toggle_add_button"):
				button.toggle_add_button()


func _on_entered_edit_mode():
	toggle_add_buttons()


func _on_exited_edit_mode():
	toggle_add_buttons()

	save()

	# If there is a popup left open we need to close it
	$EditButtonPopup.visible = false


# Function to be called when the AddButton is pressed
func AddButton_pressed(row, pos, button):
	$EditButtonPopup.show_popup(row, pos, button)


# Adds or edits a button
# row: row in which this button belongs
# pos: position in row this button is supposed to be
# button_dict: dictionary containing all keys that this button is supposed to have
# button: instance of the button from which the change was requested
func add_or_edit_button(row, pos, button_dict, button):
	var row_node := $RowSeparator.get_child(row)

	if not button.has_method("save"):
		var new_button = app_button.instance()
		# Apply button settings
		new_button.set_custom_minimum_size(button_min_size)
		replace_button(button, new_button)
		button = new_button

	# Check for valid pos
	# and child_count returns amount of children but pos starts at 0
	if pos > row_node.get_child_count() - 1:
		pos = row_node.get_child_count() - 1
	# Don't allow invalid negative or 0 number
	elif pos < 0:
		pos = 0

	edit_button_keys(button, button_dict)
	button.apply_change()

	# If a position change is requested
	if row_node.get_child(pos) != button:
		swap_buttons(row_node.get_child(pos), button)


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
	var button_pos = calculate_pos(button)
	$EditButtonPopup.show_popup(button_pos[0], button_pos[1], button)


# This calculates the position of a button
# Returns an array with [0] = row, [1] = pos
func calculate_pos(button) -> Array:
	return [button.get_parent().get_index(), button.get_index()]


# This calculates how many rows and buttons per row are possible
# based on current size
func calculate_size() -> Vector2:
	var size = get_size()
	return Vector2(floor((size.x + BUTTON_GAP) / (button_min_size.x + BUTTON_GAP)), floor((size.y + BUTTON_GAP) / (button_min_size.y + BUTTON_GAP)))


func _on_size_changed():
	max_buttons = calculate_size()
	# Because we don't want to reload a bunch of times at startup
	if not initializing:
		load_buttons()
