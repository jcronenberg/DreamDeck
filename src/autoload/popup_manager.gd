extends Node
## The manager for showing a popup.
##
## If you need to show a popup use this manager. It handles most of the setup
## you need for a popup and ensures some things, like e.g. that only 1 popup
## can be shown at a time.[br]
## The way it is meant to be used is first by calling [method init_popup].
## If you require "levels" to your popup, so you e.g. need to edit something
## within the current popup with the ability to return to the previous popup
## after, use [method push_stack_item].

@onready var _popup: SimpleWindow = SimpleWindow.new()
var _current_popup: Control:
	get = get_current_popup
var _popup_stack: Array[Control] = []
var _caller_confirm_func: Callable
var _caller_cancel_func: Callable


func _ready() -> void:
	_popup.visible = false
	_popup.connect("confirmed", _on_popup_confirmed)
	_popup.connect("cancelled", _on_popup_cancelled)
	_popup.connect("close_requested", _on_popup_close_requested)
	get_node("/root/Main").add_child(_popup)


## Initializes a new popup, freeing the whole previous stack if it existed.
## Pass your callable functions for how you want to handle the popup's
## confirm or cancel buttons/actions.
## The manager automatically frees the item(s).[br]
## [br]
## [param confirm_func] should roughly look like this:[br]
## [code]func confirm(popup_window: Control) -> bool:[/code][br]
## It should return true if the action was successful.[br]
## [br]
## [param cancel_func] should roughly look like this:[br]
## [code]func cancel(popup_window: Control) -> void:[/code][br]
## If called with [code]popup_window = null[/code] then the window was closed
## or a new [method init_popup] was requested.
## Closed is supposed to be handled as if the user cancelled all actions.
func init_popup(popup_window: Control, confirm_func: Callable, cancel_func: Callable) -> void:
	if not popup_window:
		return

	_set_current_popup(popup_window)

	_caller_confirm_func = confirm_func
	_caller_cancel_func = cancel_func


## Pushes the [param popup_window] onto the popup stack.
## If called before a [method init_popup] was called it does nothing.
func push_stack_item(popup_window: Control) -> void:
	if _popup_stack.size() == 0:
		return
	if not popup_window:
		return

	_popup_stack.append(popup_window)
	_popup.set_scene(popup_window)
	_popup.set_cancel_text("Back")


## Pops the current stack item.
## If nothing is left on the stack it disconnects the caller's functions
## and hides the popup.
func pop_stack_item() -> void:
	var stack_item: Control = _popup_stack.pop_back()
	stack_item.queue_free()
	if _popup_stack.size() > 0:
		_popup.set_scene(_popup_stack.back())
		if _popup_stack.size() == 1:
			_popup.set_cancel_text("Cancel")
	else:
		_reset_callables()
		_popup.hide()


func get_current_popup() -> Control:
	return _popup_stack[_popup_stack.size() - 1] if _popup_stack.size() > 0 else null


## Closes the current popup and disconnects the caller's functions.
func close_popup() -> void:
	while _popup_stack.size() > 0:
		pop_stack_item()


func _set_current_popup(popup_window: Control) -> void:
	if _popup_stack.size() > 0:
		_caller_cancel_func.callv([null])
		for stack_item in _popup_stack:
			stack_item.queue_free()

	_reset_callables()

	_current_popup = popup_window
	_popup_stack = [popup_window]
	_popup.set_scene(popup_window)
	_popup.set_cancel_text("Cancel")
	_popup.show()


func _on_popup_confirmed() -> void:
	if _caller_confirm_func.callv([get_current_popup()]):
		pop_stack_item()


func _on_popup_cancelled() -> void:
	_caller_cancel_func.callv([get_current_popup()])
	pop_stack_item()


func _on_popup_close_requested() -> void:
	_caller_cancel_func.callv([null])
	for stack_item in _popup_stack:
		stack_item.queue_free()
	_popup_stack = []
	_reset_callables()
	_popup.hide()


# An older callable should never actually occur, but just to be sure
func _reset_callables() -> void:
	_caller_confirm_func = func unused(__) -> bool: return true
	_caller_cancel_func = func unused(__) -> void: pass


class SimpleWindow extends Window:
	signal confirmed
	signal cancelled

	var _buttons_hbox: HBoxContainer = HBoxContainer.new()
	var _confirm_button: Button = Button.new()
	var _cancel_button: Button = Button.new()
	var _margin: MarginContainer = MarginContainer.new()
	var _vbox: VBoxContainer = VBoxContainer.new()
	var _scene_parent: MarginContainer = MarginContainer.new()


	func _init() -> void:
		set_size(Vector2(800, 400))
		set_initial_position(Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN)

		_margin.set("theme_override_constants/margin_left", 20)
		_margin.set("theme_override_constants/margin_right", 20)
		_margin.set("theme_override_constants/margin_bottom", 20)
		_margin.set("theme_override_constants/margin_top", 20)
		_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_margin)

		_scene_parent.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_vbox.add_child(_scene_parent)
		_margin.add_child(_vbox)


	func _ready() -> void:
		_confirm_button.text = "Confirm"
		_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_confirm_button.connect("pressed", _on_confirm_button_pressed)
		_cancel_button.text = "Cancel"
		_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_cancel_button.connect("pressed", _on_cancel_button_pressed)
		_buttons_hbox.size_flags_vertical = Control.SIZE_SHRINK_END
		_buttons_hbox.set("theme_override_constants/separation", 20)
		_buttons_hbox.add_child(_confirm_button)
		_buttons_hbox.add_child(_cancel_button)
		_vbox.add_child(_buttons_hbox)


	func set_scene(node: Control) -> void:
		if _scene_parent.get_child_count() > 0:
			# Should only ever be 1 but just to be sure
			for child in _scene_parent.get_children():
				_scene_parent.remove_child(child)

		_scene_parent.add_child(node)


	func set_cancel_text(text: String) -> void:
		_cancel_button.text = text


	func _on_cancel_button_pressed() -> void:
		cancelled.emit()


	func _on_confirm_button_pressed() -> void:
		confirmed.emit()
