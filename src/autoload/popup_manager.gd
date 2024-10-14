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

var _popup: SimpleWindow = SimpleWindow.new()
var _popup_stack: Array[StackItem] = []


func _ready() -> void:
	_popup.visible = false
	_popup.connect("confirmed", _on_popup_confirmed)
	_popup.connect("cancelled", _on_popup_cancelled)
	_popup.connect("close_requested", _on_popup_close_requested)
	get_node("/root/Main").add_child(_popup)


## Initializes a new popup, freeing the whole previous stack if it existed.
## The manager automatically frees the [param scene] when no longer needed.[br]
## You can pass callable functions for how you want to handle the popup's
## confirm or cancel buttons/actions.
## [br]
## [param confirm_callable] can return false if confirming should not be successful.[br]
## [param cancel_callable] can not be unsuccessful. It also gets called when the popup
## is closed.[br]
func init_popup(scene: Control,
		confirm_callable: Callable = func unused() -> bool: return true,
		cancel_callable: Callable = func unused() -> void: pass) -> void:
	if not scene:
		return

	_set_current_popup(scene, confirm_callable, cancel_callable)


## Pushes the [param scene] onto the popup stack.
## If there are no items it has the same effect as [method init_popup].
## The manager automatically frees the [param scene] when no longer needed.[br]
## You can pass callable functions for how you want to handle the popup's
## confirm or cancel buttons/actions.
## [br]
## [param confirm_callable] can return false if confirming should not be successful.[br]
## [param cancel_callable] can not be unsuccessful. It also gets called when the popup
## is closed.[br]
func push_stack_item(scene: Control,
		confirm_callable: Callable = func unused() -> bool: return true,
		cancel_callable: Callable = func unused() -> void: pass) -> void:
	if not scene:
		return

	if _popup_stack.size() == 0:
		_set_current_popup(scene, confirm_callable, cancel_callable)
	else:
		var stack_item: StackItem = _create_stack_item(scene, confirm_callable, cancel_callable)
		_popup.set_cancel_text("Back")
		_popup_stack.push_back(stack_item)


## Pops the current stack item.
## Calls neither cancel nor confirm functions.
## If nothing is left it also hides the popup.
func pop_stack_item() -> void:
	var stack_item: StackItem = _popup_stack.pop_back()
	if stack_item.control_node and is_instance_valid(stack_item.control_node):
		stack_item.control_node.queue_free()

	if _popup_stack.size() > 0:
		_popup.set_scene(_popup_stack.back().control_node)
		if _popup_stack.size() == 1:
			_popup.set_cancel_text("Cancel")
	else:
		_popup.hide()


## Get current control in popup.
func get_current_popup() -> Control:
	return _popup_stack[_popup_stack.size() - 1].control_node if _popup_stack.size() > 0 else null


## Closes the current popup.
## Also calls cancel on all items on the stack.
func close_popup() -> void:
	for stack_item in _popup_stack:
		stack_item.delete()

	_popup_stack = []
	_popup.hide()


func _set_current_popup(scene: Control, confirm_callable: Callable, cancel_callable: Callable) -> void:
	for stack_item in _popup_stack:
		stack_item.delete()

	_popup_stack = [_create_stack_item(scene, confirm_callable, cancel_callable)]
	_popup.set_cancel_text("Cancel")
	_popup.show()


func _create_stack_item(scene: Control, confirm_callable: Callable, cancel_callable: Callable) -> StackItem:
	var stack_item: StackItem = StackItem.new()
	stack_item.control_node = scene
	stack_item.confirm_callable = confirm_callable
	stack_item.cancel_callable = cancel_callable
	_popup.set_scene(stack_item.control_node)
	return stack_item


func _on_popup_confirmed() -> void:
	if _popup_stack.back().confirm():
		pop_stack_item()


func _on_popup_cancelled() -> void:
	_popup_stack.back().cancel()
	pop_stack_item()


func _on_popup_close_requested() -> void:
	for stack_item in _popup_stack:
		stack_item.delete()
	_popup_stack = []
	_popup.hide()


class SimpleWindow extends Window:
	signal confirmed
	signal cancelled

	var _buttons_hbox: HBoxContainer = HBoxContainer.new()
	var _confirm_button: Button = Button.new()
	var _cancel_button: Button = Button.new()
	var _margin: MarginContainer = MarginContainer.new()
	var _vbox: VBoxContainer = VBoxContainer.new()
	var _scene_parent: ScrollContainer = ScrollContainer.new()


	func _init() -> void:
		set_size(Vector2(1000, 600))
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

		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_scene_parent.add_child(node)


	func set_cancel_text(text: String) -> void:
		_cancel_button.text = text


	func _on_cancel_button_pressed() -> void:
		cancelled.emit()


	func _on_confirm_button_pressed() -> void:
		confirmed.emit()


class StackItem:
	var control_node: Control
	var confirm_callable: Callable
	var cancel_callable: Callable


	func cancel() -> void:
		cancel_callable.call()


	func confirm() -> bool:
		var ret_val: Variant = confirm_callable.call()
		if ret_val is bool:
			return ret_val

		return true


	func delete() -> void:
		if control_node and is_instance_valid(control_node):
			control_node.queue_free()

		cancel()
