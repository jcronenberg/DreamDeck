class_name Macroboard
extends PluginSceneBase
## A board that contains [ShellButton]s which can execute all kind of functions.

const PLUGIN_NAME = "macroboard"

## Note setting this doesn't actually change the gap currently.
## This is just used for calculating the size the [ShellButton]s can have.
## It is supposed to match what is set in [b]MacroRow[/b] in [i]theme_override_constants/separation[/i].
const BUTTON_GAP = 10

const CONFIG_PROTO: Array[Dictionary] = [{"TYPE": "INT", "KEY": "Columns", "DEFAULT_VALUE": 8},
	{"TYPE": "INT", "KEY": "Rows", "DEFAULT_VALUE": 5},
	{"TYPE": "BOOL", "KEY": "Square buttons", "DEFAULT_VALUE": false}]

## [b]Resource[/b] for creating rows.
var macro_row: PackedScene = load("res://plugins/macroboard/scenes/macro_row.tscn")

## [b]Resource[/b] for creating new [ShellButton]s.
var shell_button: PackedScene = load("res://plugins/macroboard/button_types/shell_button/shell_button.tscn")

## [b]Resource[/b] for creating new [NoButton]s.
var no_button: PackedScene = load("res://plugins/macroboard/scenes/no_button.tscn")

## The amount of rows and columns this [Macroboard] is supposed to have.
var max_buttons: Vector2

## Minimum size for all [ShellButton]s.
var button_min_size: Vector2

## Array that contains the [b]instances[/b] of all buttons.
var layout_instances: Array = []

## Flag if buttons are supposed to be maximum size or keep square (square can leave a gap at the bottom).
var keep_buttons_square: bool = true

## Instance of temporary button that gets placed when a button is being dragged.
var tmp_button

## Current Position of the temporary button in [member layout_instances].
## Is -1 when [member tmp_button] doesn't exist.
var tmp_button_position: int = -1

## Path where layout is stored.
@onready var layout_path: String = conf_dir + "layout.json"


func _init():
	config_proto = CONFIG_PROTO


func _ready():
	super()


func load_layout() -> Array:
	var layout_config: Variant = ConfLib.load_config(layout_path)
	if not layout_config:
		layout_config = []
	elif typeof(layout_config) != TYPE_ARRAY:
		push_error(layout_path, " is not the correct type.")
		queue_free()
		return []

	return layout_config as Array


## Function to be called when an existing button is pressed in edit mode.[br]
## [param button]: [b]Instance[/b] of the button itself that is calling this function.
func edit_button(button):
	$EditButtonPopup.show_popup(button)


## Adds or edits a button depending on if it is a [ShellButton] or not.[br]
## [param button]: [b]Instance[/b] of the button from which the change was requested.[br]
##                 If it is a [ShellButton] it gets edited otherwise a new [ShellButton] is created.[br]
## [param button_dict]: [Dictionary] containing all keys that this button is supposed to have.[br]
func add_or_edit_button(button, button_dict: Dictionary):
	# If button is new
	if not button.has_method("save"):
		var new_button: ShellButton = shell_button.instantiate()
		# Apply button settings
		new_button.set_custom_minimum_size(button_min_size)
		_replace_button(button, new_button)
		button = new_button

	_edit_button_keys(button, button_dict)
	button.apply_change()

	_save()


## "Deletes" [param button] [b]instance[/b] by replacing it with a [NoButton] [b]instance[/b].
func delete_button(button):
	var new_no_button = no_button.instantiate()
	new_no_button.set_custom_minimum_size(button_min_size)
	_replace_button(button, new_no_button)

	# Because we are guaranteed currently in edit mode
	new_no_button.toggle_add_button()

	_save()


## Saves [Macroboard] config via [member plugin_coordinator] and saves [member layout] via [member layout_config].[br]
## Note: This doesn't update [member layout] so before calling [member layout] must contain the latest changes.
func _save():
	ConfLib.save_config(layout_path, _create_layout_array())


## Frees all current rows.
func _free_rows():
	for row in $RowSeparator.get_children():
		row.free()


# TODO there is some performance optimization here where we could compare what is different
#      compared to just always creating from scratch.
## Loads [member layout] from [member layout_config] and then creates all [ShellButton]s accordingly.
func _create_buttons(layout: Array):
	_free_rows()

	layout_instances = []
	var button_iterator := 0
	for row in max_buttons.y:
		for button in max_buttons.x:
			var new_button

			# Only if an entry exists at this position we add it
			if layout.size() > button_iterator and layout[button_iterator]:
				new_button = shell_button.instantiate()
				_edit_button_keys(new_button, layout[button_iterator])
			else:
				new_button = no_button.instantiate()

			new_button.set_custom_minimum_size(button_min_size)

			layout_instances.append(new_button)

			button_iterator += 1


	_place_buttons()
	# Since all buttons get reset, we need to account for edit mode
	if GlobalSignals.get_edit_state():
		_toggle_add_buttons()


## Places buttons according to [member layout_instances].
func _place_buttons():
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


## Frees [param original_button] and replaces it with [param new_button].
func _replace_button(original_button, new_button):
	var row = original_button.get_parent()
	var pos = original_button.get_index()

	row.add_child(new_button)
	row.move_child(new_button, pos)

	layout_instances[layout_instances.find(original_button)] = new_button
	original_button.free()


## Toggles all [NoButton]s.
func _toggle_add_buttons():
	for row in $RowSeparator.get_children():
		for button in row.get_children():
			if button.has_method("toggle_add_button"):
				button.toggle_add_button()


## Edit all values of the [param button] [b]instance[/b].[br]
## [param button_dict]: [Dictionary] that contains all key value pairs that are supposed to be set.[br]
func _edit_button_keys(button, button_dict: Dictionary):
	# Iterate through all values that need to be set in button
	for key in button_dict.keys():
		button.set(key, button_dict[key])


## Returns the maximum size the buttons can have based on [member max_buttons] and current size.[br]
## Respects [member keep_buttons_square] flag.
func _calculate_button_size() -> Vector2:
	var macroboard_size = get_size()
	var button_size := Vector2()
	button_size.x = int(((macroboard_size.x - max_buttons.x * BUTTON_GAP) + BUTTON_GAP) / max_buttons.x)
	button_size.y = int(((macroboard_size.y - max_buttons.y * BUTTON_GAP) + BUTTON_GAP) / max_buttons.y)

	# Only return positive values
	if button_size.abs() != button_size:
		return Vector2(0, 0)

	if keep_buttons_square:
		if button_size.x > button_size.y:
			button_size.x = button_size.y
		else:
			button_size.y = button_size.x

	return button_size


# Handle button dragging
func _can_drop_data(at_position, data):
	if data.has("type") and data["type"] == "macroboard_button":
		_handle_lifted_button(at_position, data["ref"])
		return true

	return false


# Add button when dragging stops
func _drop_data(_at_position, data):
	data["ref"].visible = true
	_place_button(data["ref"])


## Entry function for a button being dragged.[br]
## [param cursor_position]: The position of the cursor relative to this macroboard.[br]
## [param lifted_button]: [b]Instance[/b] of the button itself that is calling this function.
func _handle_lifted_button(cursor_position: Vector2, lifted_button):
	if not tmp_button:
		tmp_button = no_button.instantiate()
		tmp_button.set_custom_minimum_size(button_min_size)
		layout_instances[layout_instances.find(lifted_button)] = tmp_button
	_place_tmp_button(_calculate_button_position(cursor_position))


## Calculates where in the layout array [param cursor_position] would slot in.
func _calculate_button_position(cursor_position: Vector2) -> int:
	var pos = floor(cursor_position / (button_min_size + Vector2(BUTTON_GAP, BUTTON_GAP)))
	if pos.y >= max_buttons.y: pos.y = max_buttons.y - 1
	if pos.x >= max_buttons.x: pos.x = max_buttons.x - 1
	return int(pos.y * max_buttons.x + pos.x)


## Places the [member tmp_button] [b]instance[/b] at [param pos] and updates [member tmp_button_position] accordingly.[br]
## Note: The [b]instance[/b] is also saved in [member layout_instances].
func _place_tmp_button(pos: int):
	if pos == tmp_button_position: return

	layout_instances.remove_at(layout_instances.find(tmp_button))
	layout_instances.insert(pos, tmp_button)

	tmp_button_position = pos
	_place_buttons()


## Places [param button] at [member tmp_button_position] and frees [member tmp_button].
func _place_button(button):
	layout_instances[tmp_button_position] = button
	_place_buttons()
	if tmp_button:
		tmp_button.free()
	tmp_button_position = -1

	# when button is from a different macroboard it's size may need to be adjusted
	_resize_buttons()

	_save()


## Applies [member button_min_size] to all buttons.
func _resize_buttons():
	for row in $RowSeparator.get_children():
		for child in row.get_children():
			child.set_custom_minimum_size(button_min_size)


func _on_size_changed():
	var new_button_min_size := _calculate_button_size()
	if button_min_size == new_button_min_size:
		return
	button_min_size = new_button_min_size
	_resize_buttons()


## Load the saved [Macroboard] configuration from disk.[br]
func handle_config():
	var data = config.get_as_dict()

	# Load button settings
	# button_min_size = Vector2(data["Button Settings"]["Height"], data["Button Settings"]["Width"])
	max_buttons = Vector2(data["Columns"], data["Rows"])
	keep_buttons_square = data["Square buttons"]

	# Apply settings
	_on_size_changed()
	_create_buttons(load_layout())


## Create a layout array from all existing nodes inside this [Macroboard].
func _create_layout_array() -> Array:
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
## A special merge for 2 arrays. It only overwrites entries in [param original_array]
## if there is something at that place in [param new_array] so no information is lost.
func _merge_layout_array(original_array: Array, new_array: Array) -> Array:
	if new_array.size() >= original_array.size():
		return new_array
	var ret_array := original_array.duplicate()
	var i := 0
	for value in new_array:
		ret_array[i] = value
		i += 1

	ret_array = _clean_nulls(ret_array)
	return ret_array


## Takes an array and returns a copy of the array the size of where the last non null element is located.
func _clean_nulls(array: Array) -> Array:
	var last_element := 0
	for i in array.size():
		if array[i]:
			last_element = i

	array.resize(last_element + 1)
	return array


func _on_entered_edit_mode():
	_toggle_add_buttons()


func _on_exited_edit_mode():
	_toggle_add_buttons()

	_save()

	# If there is a popup left open we need to close it
	$EditButtonPopup.visible = false
