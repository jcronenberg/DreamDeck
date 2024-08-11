class_name Macroboard
extends PluginSceneBase
## A board that contains [ShellButton]s which can execute all kind of functions.

# TODO make it a config setting
## The gap between buttons
const BUTTON_GAP = 10

var _action_button: PackedScene = load("res://plugins/macroboard/src/buttons/macro_action_button.tscn")
var _no_button: PackedScene = load("res://plugins/macroboard/src/buttons/macro_no_button.tscn")

# The amount of rows and columns this [Macroboard] is supposed to have.
var _max_buttons: Vector2

# Minimum size for all buttos.
# This is the actual size because they get added to box containers.
var _button_min_size: Vector2

# Array that contains the instances of all buttons.
var _layout_instances: Array[MacroButtonBase] = []

# Flag if buttons are supposed to be maximum size or keep square (square can leave a gap at the bottom).
var _keep_buttons_square: bool = true

# Instance of temporary button that gets placed when a button is being dragged.
var _tmp_button: MacroNoButton

# Current Position of the temporary button in [member _layout_instances].
# Is -1 when [member _tmp_button] doesn't exist.
var _tmp_button_position: int = -1

# Path where layout is stored.
@onready var _layout_path: String = conf_dir + "layout.json"


func _init() -> void:
	config.add_int("Columns", 8)
	config.add_int("Rows", 3)
	config.add_bool("Square buttons", false)


func _ready() -> void:
	super()

	%RowSeparator.set("theme_override_constants/separation", BUTTON_GAP)


## Loads layout from disk
func load_layout() -> Array:
	var layout_config: Variant = ConfLib.load_config(_layout_path)
	if not layout_config:
		layout_config = []
	elif typeof(layout_config) != TYPE_ARRAY:
		push_error(_layout_path, " is not the correct type.")
		queue_free()
		return []

	return layout_config as Array


## "Deletes" [param button] [b]instance[/b] by replacing it with a [MacroNoButton] [b]instance[/b].
func delete_button(button: MacroButtonBase) -> void:
	var new_no_button: MacroNoButton = _no_button.instantiate()
	new_no_button.set_custom_minimum_size(_button_min_size)
	replace_button(button, new_no_button)

	# Because we are guaranteed currently in edit mode
	new_no_button.toggle_add_button()

	_save_layout()


## Frees [param original_button] and replaces it with [param new_button].
func replace_button(original_button: MacroButtonBase, new_button: MacroButtonBase) -> void:
	var row: HBoxContainer = original_button.get_parent()
	var pos: int = original_button.get_index()

	row.add_child(new_button)
	row.move_child(new_button, pos)

	_layout_instances[_layout_instances.find(original_button)] = new_button
	original_button.free()

	_resize_buttons()


## Load the saved [Macroboard] configuration from disk.
func handle_config() -> void:
	var data: Dictionary = config.get_as_dict()

	# Load button settings
	_max_buttons = Vector2(data["Columns"], data["Rows"])
	_keep_buttons_square = data["Square buttons"]

	# Apply settings
	_on_size_changed()
	_create_buttons(load_layout())


# Saves layout to disk
func _save_layout() -> void:
	ConfLib.save_config(_layout_path, _create_layout_array())


# Frees all current rows.
func _free_rows() -> void:
	for row in %RowSeparator.get_children():
		row.free()


# TODO there is some performance optimization here where we could compare what is different
#      compared to just always creating from scratch.
# Creates and places all buttons from [param layout]
func _create_buttons(layout: Array) -> void:
	_free_rows()

	_layout_instances = []
	var button_iterator: int = 0
	for row in _max_buttons.y:
		for button in _max_buttons.x:
			var new_button: MacroButtonBase

			# Only if an entry exists at this position we add it
			if layout.size() > button_iterator and layout[button_iterator]:
				new_button = _action_button.instantiate()
				new_button.deserialize(layout[button_iterator])
			else:
				new_button = _no_button.instantiate()

			new_button.set_custom_minimum_size(_button_min_size)

			_layout_instances.append(new_button)

			button_iterator += 1


	_place_buttons()
	# Since all buttons get reset, we need to account for edit mode
	if GlobalSignals.get_edit_state():
		_toggle_add_buttons()


# Places buttons according to [member _layout_instances].
func _place_buttons() -> void:
	var i: int = 0
	for button in _layout_instances:
		var row: HBoxContainer
		if floori(i / _max_buttons.x) >= %RowSeparator.get_child_count():
			row = HBoxContainer.new()
			row.set("theme_override_constants/separation", BUTTON_GAP)
			%RowSeparator.add_child(row)
		else:
			row = %RowSeparator.get_child(floori(i / _max_buttons.x))
		if button.get_parent() and button.get_parent() != row:
			button.reparent(row)
		elif not button.get_parent():
			row.add_child(button)

		row.move_child(button, i % int(_max_buttons.x))

		i += 1


# Toggles all [MacroNoButton]s.
func _toggle_add_buttons() -> void:
	for row in %RowSeparator.get_children():
		for button in row.get_children():
			if button.has_method("toggle_add_button"):
				button.toggle_add_button()


# Returns the maximum size the buttons can have based on [member _max_buttons] and current size.
# Respects [member _keep_buttons_square] flag.
func _calculate_button_size() -> Vector2:
	var macroboard_size: Vector2 = get_size()
	var button_size: Vector2 = Vector2()
	button_size.x = int(((macroboard_size.x - _max_buttons.x * BUTTON_GAP) + BUTTON_GAP) / _max_buttons.x)
	button_size.y = int(((macroboard_size.y - _max_buttons.y * BUTTON_GAP) + BUTTON_GAP) / _max_buttons.y)

	# Only return positive values
	if button_size.abs() != button_size:
		return Vector2(0, 0)

	if _keep_buttons_square:
		if button_size.x > button_size.y:
			button_size.x = button_size.y
		else:
			button_size.y = button_size.x

	return button_size


# Handle button dragging
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data.has("type") and data["type"] == "macroboard_button":
		_handle_lifted_button(at_position, data["ref"])
		return true

	return false


# Add button when dragging stops
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	data["ref"].visible = true
	_place_button(data["ref"])


# Entry function for a button being dragged.
# [param cursor_position]: The position of the cursor relative to this macroboard.
# [param lifted_button]: Instance of the button itself that is calling this function.
func _handle_lifted_button(cursor_position: Vector2, lifted_button: MacroActionButton) -> void:
	if not _tmp_button:
		_tmp_button = _no_button.instantiate()
		_tmp_button.set_custom_minimum_size(_button_min_size)
		_layout_instances[_layout_instances.find(lifted_button)] = _tmp_button
	_place_tmp_button(_calculate_button_position(cursor_position))


# Calculates where in the layout array [param cursor_position] would slot in.
func _calculate_button_position(cursor_position: Vector2) -> int:
	var pos: Vector2 = floor(cursor_position / (_button_min_size + Vector2(BUTTON_GAP, BUTTON_GAP)))
	if pos.y >= _max_buttons.y: pos.y = _max_buttons.y - 1
	if pos.x >= _max_buttons.x: pos.x = _max_buttons.x - 1
	return int(pos.y * _max_buttons.x + pos.x)


# Places the [member _tmp_button] instance at [param pos] and updates [member _tmp_button_position] accordingly.
# Note: The instance is also saved in [member _layout_instances].
func _place_tmp_button(pos: int) -> void:
	if pos == _tmp_button_position: return

	_layout_instances.remove_at(_layout_instances.find(_tmp_button))
	_layout_instances.insert(pos, _tmp_button)

	_tmp_button_position = pos
	_place_buttons()


# Places [param button] at [member _tmp_button_position] and frees [member _tmp_button].
func _place_button(button: MacroActionButton) -> void:
	_layout_instances[_tmp_button_position] = button
	_place_buttons()
	if _tmp_button:
		_tmp_button.free()
	_tmp_button_position = -1

	# when button is from a different macroboard it's size may need to be adjusted
	_resize_buttons()

	_save_layout()


# Applies [member _button_min_size] to all buttons.
func _resize_buttons() -> void:
	for row in %RowSeparator.get_children():
		for child in row.get_children():
			child.set_custom_minimum_size(_button_min_size)


# Called when size of the [Macroboard] changes. Updates [member _button_min_size] and resizes buttons.
func _on_size_changed() -> void:
	var new_button_min_size: Vector2 = _calculate_button_size()
	if _button_min_size == new_button_min_size:
		return
	_button_min_size = new_button_min_size
	_resize_buttons()


# Create a layout array from all existing nodes inside this [Macroboard].
func _create_layout_array() -> Array:
	var button_array: Array = []
	for row in %RowSeparator.get_children():
		for button in row.get_children():
			if button.has_method("serialize"):
				button_array.append(button.serialize())
			else:
				button_array.append(null)

	return button_array


func _on_entered_edit_mode() -> void:
	_toggle_add_buttons()


func _on_exited_edit_mode() -> void:
	_toggle_add_buttons()

	_save_layout()
