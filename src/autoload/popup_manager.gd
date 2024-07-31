extends Node
## The manager for showing a popup.
##
## If you need to show a popup use this manager. It handles most of the setup
## you need for a popup and ensures some things, like e.g. that only 1 popup
## can be shown at a time.[br]
## The way it is meant to be used is first by calling [method init_popup].
## If you require "levels" to your popup, so you e.g. need to edit something
## within the current popup with the ability to return to the previous popup
## after, use [method add_stack_item].

## Emitted when popup was confirmed. [param popup_window] is the current window.
signal popup_confirmed(popup_window: Control)

## Emitted when popup was cancelled. [param popup_window] is the current window.
## If emitted with [code]popup_window = null[/code] then the window was closed
## or a new [method init_popup] was requested.
## Closed is supposed to be handled as if the user cancelled all actions.
signal popup_cancelled(popup_window: Control)


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
## [signal popup_confirmed] and [signal popup_cancelled] signals.
## The manager automatically connects and disconnects these functions.
func init_popup(popup_window: Control, confirm_func: Callable, cancel_func: Callable) -> void:
	_set_current_popup(popup_window)

	_caller_confirm_func = confirm_func
	popup_confirmed.connect(confirm_func)
	_caller_cancel_func = cancel_func
	popup_cancelled.connect(cancel_func)


## Adds the [param popup_window] to the popup stack.
## If called before a [method init_popup] was called it does nothing.
func add_stack_item(popup_window: Control) -> void:
	if _popup_stack.size() == 0:
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
		_disconnect_caller()
		_popup.hide()


func get_current_popup() -> Control:
	return _popup_stack[_popup_stack.size() - 1] if _popup_stack.size() > 0 else null


func _set_current_popup(popup_window: Control) -> void:
	if _popup_stack.size() > 0:
		emit_signal("popup_cancelled", null)

		for stack_item in _popup_stack:
			stack_item.queue_free()

	_disconnect_caller()

	_current_popup = popup_window
	_popup_stack = [popup_window]
	_popup.set_scene(popup_window)
	_popup.set_cancel_text("Cancel")
	_popup.show()


func _disconnect_caller() -> void:
	if not _caller_confirm_func or not _caller_cancel_func:
		return
	if popup_confirmed.is_connected(_caller_confirm_func):
		popup_confirmed.disconnect(_caller_confirm_func)
	if popup_cancelled.is_connected(_caller_cancel_func):
		popup_cancelled.disconnect(_caller_cancel_func)


func _on_popup_confirmed() -> void:
	emit_signal("popup_confirmed", get_current_popup())
	pop_stack_item()


func _on_popup_cancelled() -> void:
	emit_signal("popup_cancelled", get_current_popup())
	pop_stack_item()


func _on_popup_close_requested() -> void:
	emit_signal("popup_cancelled", null)
	for stack_item in _popup_stack:
		stack_item.queue_free()
	_popup_stack = []
	_disconnect_caller()
	_popup.hide()


class SimpleWindow extends Window:
	signal confirmed
	signal cancelled

	@onready var _buttons_hbox: HBoxContainer = HBoxContainer.new()
	@onready var _confirm_button: Button = Button.new()
	@onready var _cancel_button: Button = Button.new()
	var _margin: MarginContainer
	var _vbox: VBoxContainer
	var _control: Control


	func _init() -> void:
		set_size(Vector2(800, 400))
		set_initial_position(Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN)

		_margin = MarginContainer.new()
		_margin.set("theme_override_constants/margin_left", 20)
		_margin.set("theme_override_constants/margin_right", 20)
		_margin.set("theme_override_constants/margin_bottom", 20)
		_margin.set("theme_override_constants/margin_top", 20)
		_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_margin)

		_vbox = VBoxContainer.new()
		_control = Control.new()
		_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_vbox.add_child(_control)
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
		if _control.get_child_count() > 0:
			# Should only ever be 1 but just to be sure
			for child in _control.get_children():
				_control.remove_child(child)

		_control.add_child(node)


	func set_cancel_text(text: String) -> void:
		_cancel_button.text = text


	func _on_cancel_button_pressed() -> void:
		emit_signal("cancelled")


	func _on_confirm_button_pressed() -> void:
		emit_signal("confirmed")
