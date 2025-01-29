class_name Macroboard
extends PluginSceneBase
## A board that contains [ShellButton]s which can execute all kind of functions.

## WARNING! Should pretty much never be used outside of the [Macroboard] instance itself.[br][br]
## Signal that gets emitted when confirm dialog gets closed
## with the bool value representing true if confirmed, otherwise false.[br]
## This is necessary because awaiting both [ConfirmationDialog] signals,
## confirmed and canceled is not possible.
signal confirm_dialog_closed(bool)

# TODO make it a config setting
## The gap between buttons
const BUTTON_GAP = 10

var _action_button: PackedScene = load(
	"res://plugins/macroboard/src/buttons/macro_action_button.tscn"
)
var _no_button: PackedScene = load("res://plugins/macroboard/src/buttons/macro_no_button.tscn")

# The amount of rows and columns this [Macroboard] is supposed to have.
var _max_buttons: Vector2

# Minimum size for all buttos.
# This is the actual size because they get added to box containers.
var _button_min_size: Vector2

# Array that contains the instances of all buttons.
var _layout_instances: Array[MacroButtonBase] = []

# Flag if buttons are supposed to be maximum size or keep square
# (square can leave a gap at the bottom).
var _keep_buttons_square: bool = true

# Position of removed button when a button from a different [Macroboard]
# was dragged to this [Macroboard].
var _removed_button_pos: int = -1

# Current Position of the dragged button in [member _layout_instances].
# Is -1 when no button is being dragged in this [Macroboard].
var _dragged_button_pos: int = -1

# Path where layout is stored.
@onready var _layout_path: String = conf_dir.path_join("layout.json")


func _init() -> void:
	config.add_int("Columns", "columns", 8)
	config.add_int("Rows", "rows", 3)
	config.add_bool("Square buttons", "square_buttons", false)


func _ready() -> void:
	super()

	add_to_group("macroboards")

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
	replace_button(button, _create_no_button())

	save_layout()


## Frees [param original_button] and replaces it with [param new_button].
func replace_button(original_button: MacroButtonBase, new_button: MacroButtonBase) -> void:
	var row: HBoxContainer = original_button.get_parent()
	var pos: int = original_button.get_index()

	row.add_child(new_button)
	row.move_child(new_button, pos)

	_layout_instances[_layout_instances.find(original_button)] = new_button
	original_button.free()

	_resize_buttons()
	save_layout()


func add_action_button(no_button: MacroNoButton, button_dict: Dictionary) -> void:
	replace_button(no_button, _create_action_button(button_dict))


## Load the saved [Macroboard] configuration from disk.
func handle_config() -> void:
	var data: Dictionary = config.get_as_dict()

	# Load button settings
	_max_buttons = Vector2(data["columns"], data["rows"])
	_keep_buttons_square = data["square_buttons"]

	# Apply settings
	_on_size_changed()
	_create_buttons(load_layout())


## Overwrite confirm function, so it will check for button deletion and ask user.
func edit_config() -> void:
	var config_editor: Config.ConfigEditor = config.generate_editor()
	PopupManager.init_popup([config_editor], _check_apply_and_save_config.bind(config_editor))


## Saves the current layout to disk.
func save_layout() -> void:
	ConfLib.save_config(_layout_path, _create_layout_array())


## Resets internal values associated with button dragging.
func reset_dragging_state() -> void:
	_dragged_button_pos = -1
	_removed_button_pos = -1


## Associates all required signals for a [param action_button] to this [Macroboard].
## Also removes all previous connections.
func associate_signals(action_button: MacroActionButton) -> void:
	# Disconnect from previous
	for button_signal in action_button.button_changed.get_connections():
		action_button.button_changed.disconnect(button_signal.callable)
	for button_signal in action_button.button_deletion_requested.get_connections():
		action_button.button_deletion_requested.disconnect(button_signal.callable)

	# Connect to this macroboard
	action_button.button_changed.connect(save_layout)
	action_button.button_deletion_requested.connect(
		delete_button.bind(action_button), CONNECT_DEFERRED
	)


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
				new_button = _create_action_button(layout[button_iterator])
			else:
				new_button = _create_no_button()

			_layout_instances.append(new_button)

			button_iterator += 1

	_place_buttons()
	# Since all buttons get reset, we need to account for edit mode
	_toggle_add_buttons(GlobalSignals.get_edit_state())


func _create_action_button(button_dict: Dictionary) -> MacroActionButton:
	var action_button: MacroActionButton = _action_button.instantiate()
	# deserialize before connecting button_changed signal, because it emits button_changed
	action_button.deserialize(button_dict)
	associate_signals(action_button)
	action_button.set_custom_minimum_size(_button_min_size)
	return action_button


func _create_no_button() -> MacroNoButton:
	var no_button: MacroNoButton = _no_button.instantiate()
	no_button.replace_button.connect(add_action_button, CONNECT_DEFERRED)
	no_button.button_deletion_requested.connect(delete_button.bind(no_button), CONNECT_DEFERRED)
	no_button.set_custom_minimum_size(_button_min_size)
	no_button.set_add_button(GlobalSignals.get_edit_state())
	return no_button


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
func _toggle_add_buttons(state: bool) -> void:
	for row in %RowSeparator.get_children():
		for button in row.get_children():
			if button is MacroNoButton:
				button.set_add_button(state)


# Returns the maximum size the buttons can have based on [member _max_buttons] and current size.
# Respects [member _keep_buttons_square] flag.
func _calculate_button_size() -> Vector2:
	var macroboard_size: Vector2 = get_size()
	var button_size: Vector2 = Vector2()
	button_size.x = int(
		((macroboard_size.x - _max_buttons.x * BUTTON_GAP) + BUTTON_GAP) / _max_buttons.x
	)
	button_size.y = int(
		((macroboard_size.y - _max_buttons.y * BUTTON_GAP) + BUTTON_GAP) / _max_buttons.y
	)

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
		if not _has_space() and not _layout_instances.has(data["ref"]):
			return false
		_handle_lifted_button(at_position, data["ref"])
		return true

	return false


func _has_space() -> bool:
	for button in _layout_instances:
		if button is MacroNoButton:
			return true

	return false


# Entry function for a button being dragged.
# [param cursor_position]: The position of the cursor relative to this macroboard.
# [param lifted_button]: Instance of the button itself that is calling this function.
func _handle_lifted_button(cursor_position: Vector2, lifted_button: MacroActionButton) -> void:
	lifted_button.set_custom_minimum_size(_button_min_size)
	# Just started dragging
	if not lifted_button.dragging_macroboard:
		_removed_button_pos = _layout_instances.find(lifted_button)
		assert(_removed_button_pos > -1)
	if lifted_button.dragging_macroboard != self:
		if lifted_button.dragging_macroboard:
			lifted_button.dragging_macroboard._add_removed_button(lifted_button)
		lifted_button.dragging_macroboard = self
	_place_dragging_button(_calculate_button_position(cursor_position), lifted_button)


# Calculates where in the layout array [param cursor_position] would slot in.
func _calculate_button_position(cursor_position: Vector2) -> int:
	var pos: Vector2 = floor(cursor_position / (_button_min_size + Vector2(BUTTON_GAP, BUTTON_GAP)))
	if pos.y >= _max_buttons.y:
		pos.y = _max_buttons.y - 1
	if pos.x >= _max_buttons.x:
		pos.x = _max_buttons.x - 1
	return int(pos.y * _max_buttons.x + pos.x)


# Makes space and places the [param button] at [param pos].
# Note: The instance is also saved in [member _layout_instances].
func _place_dragging_button(pos: int, button: MacroActionButton) -> void:
	if pos == _dragged_button_pos:
		return

	if not _layout_instances.has(button):
		_make_space_for_dragging_button()
		_layout_instances.insert(pos, button)
	elif _dragged_button_pos != -1:
		_layout_instances.remove_at(_dragged_button_pos)
		_layout_instances.insert(pos, button)

	_dragged_button_pos = pos
	button.dragging_macroboard = self
	_place_buttons()


# Finds the first free space in reverse order and then removes that [MacroNoButton].
# Should only be called if it has already been validated that there is space(a [MacroNoButton])
# to remove.
func _make_space_for_dragging_button() -> void:
	if _removed_button_pos < 0:
		for i in range(_layout_instances.size() - 1, -1, -1):
			if _layout_instances[i] is MacroNoButton:
				_removed_button_pos = i
				break

	assert(_removed_button_pos > -1)

	# QUEUE_free() somehow is important here otherwise the engine crashes.
	_layout_instances[_removed_button_pos].queue_free()
	_layout_instances.remove_at(_removed_button_pos)


# Removes the lifted button from this [Macroboard] and adds a new [MacroNoButton].
# If [member _removed_button_pos] is set it will try to insert it at this position
# otherwise it is appended to the end.
func _add_removed_button(lifted_button: MacroActionButton) -> void:
	var button: MacroNoButton = _create_no_button()

	if _removed_button_pos < 0:
		_removed_button_pos = _layout_instances.find(lifted_button)

	assert(_removed_button_pos > -1)
	_layout_instances.erase(lifted_button)
	_layout_instances.insert(_removed_button_pos, button)

	_dragged_button_pos = -1
	_place_buttons()


# Applies [member _button_min_size] to all buttons.
func _resize_buttons() -> void:
	for row in %RowSeparator.get_children():
		for child in row.get_children():
			child.set_custom_minimum_size(_button_min_size)


# Called when size of the [Macroboard] changes.
# Updates [member _button_min_size] and resizes buttons.
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
	_toggle_add_buttons(true)


func _on_exited_edit_mode() -> void:
	_toggle_add_buttons(false)

	save_layout()
	config.save()


# Removes up to [param count] [MacroNoButton]s starting from the back of the layout.[br]
# [param count] The maximum number of [MacroNoButton]s to remove.[br]
# Returns true if [param count] [MacroNoButton]s were deleted.
func _remove_no_buttons(count: int) -> bool:
	var no_buttons_removed: int = 0

	# Traverse [member _layout_instances] from the back
	for i in range(_layout_instances.size() - 1, -1, -1):
		if no_buttons_removed >= count:
			break
		if _layout_instances[i] is MacroNoButton:
			_layout_instances[i].free()
			_layout_instances.remove_at(i)
			no_buttons_removed += 1

	return count >= no_buttons_removed


# Checks if config changes can be applied without losing any buttons.
# In case it can't, it shows a deletion warning.
# If either the deletion warning was confirmed or changes can be applied without
# losing buttons, it frees as many [MacroNoButton]s as it can/needs to from the
# scene and also from [member _layout_instances].
# Returns false if user declined the deletion warning.
# Note: this only deletes [MacroNoButton]s, it will never delete any other buttons.
func _on_macroboard_config_change(new_config_dict: Dictionary) -> bool:
	var new_layout_size: int = new_config_dict["columns"] * new_config_dict["rows"]
	var max_buttons_diff: int = _layout_instances.size() - new_layout_size
	# If less max buttons than previously
	if max_buttons_diff > 0:
		if _create_layout_array().count(null) < max_buttons_diff:
			if await _show_button_deletion_warning():
				_remove_no_buttons(max_buttons_diff)
				return true

			return false

		_remove_no_buttons(max_buttons_diff)

	return true


# Shows and returns the value of a [ConfirmationDialog],
# warning the user of imminent button deletion.
func _show_button_deletion_warning() -> bool:
	var confirm_dialog: ConfirmationDialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = """[center]WARNING!
Existing buttons will be deleted by the size change (starting from the back).
Are you certain you want to continue?[/center]
"""
	add_child(confirm_dialog)
	confirm_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	confirm_dialog.show()
	confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
	confirm_dialog.canceled.connect(_on_confirm_dialog_canceled)
	var ret: bool = await confirm_dialog_closed
	confirm_dialog.queue_free()
	return ret


func _on_confirm_dialog_confirmed() -> void:
	confirm_dialog_closed.emit(true)


func _on_confirm_dialog_canceled() -> void:
	confirm_dialog_closed.emit(false)


# Function for [method Macroboard.edit_config] when popup gets confirmed.
func _check_apply_and_save_config(config_editor: Config.ConfigEditor) -> void:
	if await _on_macroboard_config_change(config_editor.serialize()):
		# Need to save before applying, because it applies from disk
		# and the deleted [MacroNoButton]s weren't saved before.
		save_layout()
		config_editor.apply()
		config_editor.save()
