extends Control
class_name Macroboard

# Constants
const PLUGIN_NAME = "Macroboard"
const BUTTON_GAP = 10
const DEFAULT_CONFIG := {
	"Size": {
		"X": 8,
		"Y": 5
		},
	"Square buttons": true
	}

# Global nodes
@onready var global_signals = get_node("/root/GlobalSignals")

# Global vars
var macro_row = load("res://plugins/Macroboard/scenes/MacroRow.tscn")
var app_button = load("res://plugins/Macroboard/scenes/AppButton.tscn")
var no_button = load("res://plugins/Macroboard/scenes/NoButton.tscn")

var max_buttons: Vector2
var button_min_size: Vector2

func _ready():
	global_signals.connect("entered_edit_mode", Callable(self, "_on_entered_edit_mode"))
	global_signals.connect("exited_edit_mode", Callable(self, "_on_exited_edit_mode"))
	global_signals.connect("plugin_configs_changed", Callable(self, "_on_plugin_configs_changed"))
	load_config()
	layout_config.load_config()
	_on_size_changed()
	load_buttons()


@onready var plugin_loader := get_node("/root/PluginLoader")
@onready var conf_dir = plugin_loader.get_conf_dir(PLUGIN_NAME)
# Page0 hardcoded for now, because we don't support multiple pages yet
@onready var layout_config = load("res://scripts/global/Config.gd").new({"Page0": []}, conf_dir + "layout.json")
var layout
var layout_instances := []
var keep_buttons_square := true


func generate_1d_layout() -> Array:
	var array := []
	for row in layout["Page0"]:
		if not row:
			continue
		for value in row:
			array.append(value)
	return array


# FIXME This is a hack, because on startup the window gets resized a lot
# so we need to wait for it all to settle and then we can handle adding buttons
# this leads to way faster startup times
# But this may also lead to problems in the future so look here if something is acting strange
func _on_plugin_configs_changed():
	load_config()
	_on_size_changed()
	load_buttons()


# Loads the saved configuration
func load_config():
	var data = plugin_loader.get_plugin_config(PLUGIN_NAME, DEFAULT_CONFIG)

	if not data or data == {}:
		return

	# Load button settings
	# button_min_size = Vector2(data["Button Settings"]["Height"], data["Button Settings"]["Width"])
	max_buttons = Vector2(data["Size"]["X"], data["Size"]["Y"])
	keep_buttons_square = data["Square buttons"]


func create_layout_array() -> Array:
	var button_array := []
	for row in $RowSeparator.get_children():
		for button in row.get_children():
			if button.has_method("save"):
				button_array.append(button.save())
			else:
				button_array.append(null)

	return button_array


# This is so we don't overwrite/clear existing buttons only because
# they aren't currently displayed e.g. because of current window size
func merge_layout_array(original_array: Array, new_array: Array) -> Array:
	if new_array.size() >= original_array.size():
		return new_array
	var ret_array := original_array.duplicate()
	ret_array.resize(new_array.size())
	var i := 0
	for value in new_array:
		ret_array[i] = value
		i += 1

	ret_array = clean_nulls(ret_array)
	return ret_array


func clean_nulls(array: Array) -> Array:
	var last_element := 0
	for i in array.size():
		if array[i]:
			last_element = i

	array.resize(last_element + 1)
	return array


func save():
	plugin_loader.save_plugin_config(PLUGIN_NAME, {"Button Settings": {"Height": button_min_size.x, "Width": button_min_size.y}})

	layout["Page0"] = merge_layout_array(layout["Page0"], create_layout_array())
	layout_config.change_config(layout)
	layout_config.save()



func free_rows():
	for row in $RowSeparator.get_children():
		row.free()


# TODO there is some performance optimization here where we could compare what is different
#      compared to just always creating from scratch.
func load_buttons():
	free_rows()

	if not layout:
		layout = layout_config.get_config()

	# if old style, convert to new style
	# FIXME remove
	if layout["Page0"].size() != 0 and typeof(layout["Page0"][0]) == TYPE_ARRAY:
		layout["Page0"] = generate_1d_layout()

	layout_instances = []
	var button_iterator := 0
	for row in max_buttons.y:
		for button in max_buttons.x:
			var new_button

			# Only if an entry exists at this position we add it
			if layout["Page0"].size() > button_iterator and layout["Page0"][button_iterator]:
				new_button = app_button.instantiate()
				edit_button_keys(new_button, layout["Page0"][button_iterator])
			else:
				new_button = no_button.instantiate()

			new_button.set_custom_minimum_size(button_min_size)

			layout_instances.append(new_button)

			button_iterator += 1


	place_buttons()
	# Since all buttons get reset, we need to account for edit mode
	if global_signals.get_edit_state():
		toggle_add_buttons()


func place_buttons():
	var i := 0
	for button in layout_instances:
		var row
		if floori(i / max_buttons.x) >= $RowSeparator.get_child_count():
			row = macro_row.instantiate()
			$RowSeparator.add_child(row)
		else:
			row = $RowSeparator.get_child(floori(i / max_buttons.x))
		if button.get_parent() and button.get_parent() != row:
			button.reparent(row)
		elif not button.get_parent():
			row.add_child(button)

		row.move_child(button, i % int(max_buttons.x))

		i += 1


# Removes original_button and replaces it with new_button
func replace_button(original_button, new_button):
	var row = original_button.get_parent()
	var pos = original_button.get_index()

	row.add_child(new_button)
	row.move_child(new_button, pos)

	layout_instances[layout_instances.find(original_button)] = new_button
	original_button.queue_free()


# "Deletes" a button by replacing it with a no_button instance
func delete_button(button):
	var new_no_button = no_button.instantiate()
	new_no_button.set_custom_minimum_size(button_min_size)
	replace_button(button, new_no_button)

	# Because we are guaranteed currently in edit mode
	new_no_button.toggle_add_button()



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


# Adds or edits a button
# row: row in which this button belongs
# pos: position in row this button is supposed to be
# button_dict: dictionary containing all keys that this button is supposed to have
# button: instance of the button from which the change was requested
func add_or_edit_button(button, button_dict: Dictionary):
	# If button is new
	if not button.has_method("save"):
		var new_button = app_button.instantiate()
		# Apply button settings
		new_button.set_custom_minimum_size(button_min_size)
		replace_button(button, new_button)
		button = new_button

	edit_button_keys(button, button_dict)
	button.apply_change()

	layout["Page0"] = merge_layout_array(layout["Page0"], create_layout_array())


# Edits all keys of a button instance with given dict values
# button: scene of button that gets edited
# button_dict: dict that contains all key value pairs that need to be set
func edit_button_keys(button, button_dict: Dictionary):
	# Iterate through all values that need to be set in button
	for key in button_dict.keys():
		# Only set attribute if value is set (may be unnecessary)
		if button_dict[key]:
			button.set(key, button_dict[key])


# Function to be called when an existing button is pressed in edit mode
# button: the instance of the button itself calling this function
func edit_button(button):
	$EditButtonPopup.show_popup(button)



# This calculates the position of a button
# Returns an array with [0] = row, [1] = pos
func _on_size_changed():
	var new_button_min_size := calculate_button_size()
	if button_min_size == new_button_min_size:
		return
	button_min_size = new_button_min_size
	resize_buttons()


# This calculates how many rows and buttons per row are possible
# based on current size
func calculate_button_size() -> Vector2:
	var macroboard_size = get_size()
	var button_size := Vector2()
	button_size.x = int((macroboard_size.x - max_buttons.x * BUTTON_GAP) / max_buttons.x)
	button_size.y = int((macroboard_size.y - max_buttons.y * BUTTON_GAP) / max_buttons.y)

	# Only return positive values
	if button_size.abs() != button_size:
		return Vector2(0, 0)

	if keep_buttons_square:
		if button_size.x > button_size.y:
			button_size.x = button_size.y
		else:
			button_size.y = button_size.x

	return button_size


var tmp_button
var tmp_button_position := -1


func handle_lifted_button(cursor_position: Vector2, lifted_button):
	if not tmp_button:
		tmp_button = no_button.instantiate()
		tmp_button.set_custom_minimum_size(button_min_size)
		layout_instances[layout_instances.find(lifted_button)] = tmp_button
	place_tmp_button(calculate_button_position(cursor_position))


func calculate_button_position(cursor_position: Vector2) -> int:
	var pos = floor(cursor_position / (button_min_size + Vector2(BUTTON_GAP, BUTTON_GAP)))
	if pos.y >= max_buttons.y: pos.y = max_buttons.y - 1
	if pos.x >= max_buttons.x: pos.x = max_buttons.x - 1
	return int(pos.y * max_buttons.x + pos.x)


func place_tmp_button(pos: int):
	if pos == tmp_button_position: return

	layout_instances.remove_at(layout_instances.find(tmp_button))
	layout_instances.insert(pos, tmp_button)

	tmp_button_position = pos
	place_buttons()


func place_button(button):
	layout_instances[tmp_button_position] = button
	place_buttons()
	if tmp_button:
		tmp_button.free()
	tmp_button_position = -1


func resize_buttons():
	for row in $RowSeparator.get_children():
		for child in row.get_children():
			child.set_custom_minimum_size(button_min_size)
