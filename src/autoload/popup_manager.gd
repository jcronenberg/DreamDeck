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

var _popup: SimpleWindow
var _popup_stack: Array[StackItem] = []


# Adds a _popup to the scene tree
func _process(_delta: float) -> void:
	if not _popup or is_instance_valid(_popup):
		var main: Control = get_node_or_null("/root/Main")
		if main:
			_add_popup_to_tree()
			set_process(false)


## Initializes a new popup, freeing the whole previous stack if it existed.
## Multiple [param scenes] can be supplied, which will be separate tabs in the popup.
## The manager automatically frees the [param scenes] when no longer needed.[br]
## You can pass callable functions for how you want to handle the popup's
## confirm or cancel buttons/actions.
## [br]
## [param confirm_callable] can return false if confirming should not be successful.[br]
## [param cancel_callable] can not be unsuccessful. It also gets called when the popup
## is closed.[br]
func init_popup(scenes: Array[Control],
	confirm_callable: Callable = func unused() -> bool: return true,
		cancel_callable: Callable = func unused() -> void: pass) -> void:
	if not scenes:
		return

	_set_current_popup(scenes, confirm_callable, cancel_callable)


## Pushes the [param scenes] onto the popup stack.
## Multiple [param scenes] can be supplied, which will be separate tabs in the popup.
## If there are no items it has the same effect as [method init_popup].
## The manager automatically frees the [param scenes] when no longer needed.[br]
## You can pass callable functions for how you want to handle the popup's
## confirm or cancel buttons/actions.
## [br]
## [param confirm_callable] can return false if confirming should not be successful.[br]
## [param cancel_callable] can not be unsuccessful. It also gets called when the popup
## is closed.[br]
func push_stack_item(scenes: Array[Control],
		confirm_callable: Callable = func unused() -> bool: return true,
		cancel_callable: Callable = func unused() -> void: pass) -> void:
	if not scenes:
		return

	if _popup_stack.size() == 0:
		_set_current_popup(scenes, confirm_callable, cancel_callable)
	else:
		_popup_stack.back().previously_selected_control_id = _popup.get_selected_control_id()
		var stack_item: StackItem = _create_stack_item(scenes, confirm_callable, cancel_callable)
		_popup.set_cancel_text("Back")
		_popup_stack.push_back(stack_item)


## Pops the current stack item.
## Calls neither cancel nor confirm functions.
## If nothing is left it also hides the popup.
func pop_stack_item() -> void:
	var stack_item: StackItem = _popup_stack.pop_back()
	stack_item.free_nodes()

	if _popup_stack.size() > 0:
		_popup.set_scene(_popup_stack.back().control_nodes)
		_popup.set_selected_control_id(_popup_stack.back().previously_selected_control_id)
		if _popup_stack.size() == 1:
			_popup.set_cancel_text("Cancel")
	else:
		_popup.hide()


## Get currently selected control in popup.
func get_current_popup() -> Control:
	if _popup_stack.size() == 0:
		return null
	var nodes: Array[Control] = _popup_stack.back().control_nodes
	return nodes[_popup.get_selected_control_id()]


## Get all tabs in the current popup.
func get_current_popup_tabs() -> Array[Control]:
	if _popup_stack.size() == 0:
		return []
	return _popup_stack.back().control_nodes


## Closes the current popup.
## Also calls cancel on all items on the stack.
func close_popup() -> void:
	for stack_item in _popup_stack:
		stack_item.free_nodes()
		stack_item.cancel()

	_popup_stack = []
	_popup.hide()


func _set_current_popup(scenes: Array[Control], confirm_callable: Callable, cancel_callable: Callable) -> void:
	for stack_item in _popup_stack:
		stack_item.free_nodes()
		stack_item.cancel()

	_popup_stack = [_create_stack_item(scenes, confirm_callable, cancel_callable)]
	_popup.set_cancel_text("Cancel")
	_popup.show()


func _create_stack_item(scenes: Array[Control], confirm_callable: Callable, cancel_callable: Callable) -> StackItem:
	var stack_item: StackItem = StackItem.new()
	stack_item.control_nodes = scenes
	stack_item.confirm_callable = confirm_callable
	stack_item.cancel_callable = cancel_callable
	_popup.set_scene(stack_item.control_nodes)
	return stack_item


func _on_popup_confirmed() -> void:
	if _popup_stack.back().confirm():
		pop_stack_item()


func _on_popup_cancelled() -> void:
	_popup_stack.back().cancel()
	pop_stack_item()


func _on_popup_close_requested() -> void:
	for stack_item in _popup_stack:
		stack_item.free_nodes()
		stack_item.cancel()
		_popup_stack = []
		_popup.hide()


func _add_popup_to_tree() -> void:
	_popup = SimpleWindow.new()
	_popup.visible = false
	_popup.confirmed.connect(_on_popup_confirmed)
	_popup.cancelled.connect(_on_popup_cancelled)
	_popup.close_requested.connect(_on_popup_close_requested)
	get_node("/root/Main").add_child(_popup)
	_popup.tree_exited.connect(_on_popup_tree_exited)


# When popup has exited the tree start processing to add a new popup to the scene.
func _on_popup_tree_exited() -> void:
	set_process(true)


class SimpleWindow extends Window:
	signal confirmed
	signal cancelled

	var _buttons_hbox: HBoxContainer = HBoxContainer.new()
	var _confirm_button: Button = Button.new()
	var _cancel_button: Button = Button.new()
	var _margin: MarginContainer = MarginContainer.new()
	var _vbox: VBoxContainer = VBoxContainer.new()
	var _scene_parent: TabContainer = TabContainer.new()


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
		_vbox.add_theme_constant_override("separation", 10)
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


	func set_scene(nodes: Array[Control]) -> void:
		for scroll_container in _scene_parent.get_children():
			for margin in scroll_container.get_children():
				for node in margin.get_children():
					# Need to remove nodes from scene tree, before we can free the parents
					# otherwise the nodes would be freed and could not be reused later
					margin.remove_child(node)
			# No queue_free here otherwise naming breaks because collisions can happen
			scroll_container.free()

		for node in nodes:
			var scroll_container: ScrollContainer = ScrollContainer.new()
			if node.name:
				scroll_container.name = node.name

			var margin: MarginContainer = MarginContainer.new()
			if nodes.size() > 1:
				margin.add_theme_constant_override("margin_top", 10)
			margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
			margin.add_child(node)
			scroll_container.add_child(margin)
			_scene_parent.add_child(scroll_container)

		_scene_parent.tabs_visible = nodes.size() > 1


	func set_cancel_text(text: String) -> void:
		_cancel_button.text = text


	func get_selected_control_id() -> int:
		return _scene_parent.current_tab


	func set_selected_control_id(id: int) -> void:
		_scene_parent.current_tab = id


	func _on_cancel_button_pressed() -> void:
		cancelled.emit()


	func _on_confirm_button_pressed() -> void:
		confirmed.emit()


class StackItem:
	var control_nodes: Array[Control]
	var confirm_callable: Callable
	var cancel_callable: Callable
	## When a stack item gets selected again, this ensures we stay on the same tab
	var previously_selected_control_id: int = 0


	func cancel() -> void:
		cancel_callable.call()


	func confirm() -> bool:
		var ret_val: Variant = confirm_callable.call()
		if ret_val is bool:
			return ret_val

		return true


	func free_nodes() -> void:
		for control_node in control_nodes:
			if control_node and is_instance_valid(control_node):
				control_node.queue_free()
