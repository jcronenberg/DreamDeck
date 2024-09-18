class_name MacroButtonBase
extends Button

var _actions_editor: ActionsEditor
var _config_editor: Config.ConfigEditor
var _config: Config = Config.new()


func _init():
	_config.add_string("Button label", "button_label", "")
	_config.add_string("Icon path", "icon_path", "")
	_config.add_bool("Show button label", "show_button_label", false)


func get_macroboard() -> Macroboard:
	var macroboard: Variant = get_parent()
	while not macroboard is Macroboard:
		macroboard = macroboard.get_parent()

	return macroboard


func open_editor(new_button: bool = false) -> void:
	var tab_container: TabContainer = TabContainer.new()
	tab_container.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox: VBoxContainer = VBoxContainer.new()
	var margin: MarginContainer = MarginContainer.new()
	margin.set("theme_override_constants/margin_top", 10)
	margin.set("theme_override_constants/margin_bottom", 10)
	margin.name = "Button settings"
	_config_editor = _config.generate_editor()
	_config_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_config_editor)
	margin.add_child(vbox)
	tab_container.add_child(margin)

	if not new_button:
		var button: Button = Button.new()
		button.text = "Delete Button"
		button.connect("pressed", _on_delete_button_pressed)
		vbox.add_child(button)

	margin = MarginContainer.new()
	margin.set("theme_override_constants/margin_top", 10)
	margin.set("theme_override_constants/margin_bottom", 10)
	margin.name = "Actions"
	_actions_editor = ActionsEditor.new()
	_actions_editor.connect("new_action_requested", _on_new_action_requested)
	margin.add_child(_actions_editor)
	tab_container.add_child(margin)
	PopupManager.init_popup(tab_container, _on_popup_confirmed, func not_required(__): pass)


func _on_new_action_requested() -> void:
	PopupManager.add_stack_item(PluginCoordinator.PluginActionSelector.new())


func _on_popup_confirmed(popup_window: Control) -> void:
	if popup_window is PluginCoordinator.PluginActionSelector:
		var action: PluginCoordinator.PluginActionDefinition = popup_window.get_selected_action()
		if action:
			_actions_editor.add_action(action)

		return


# Function called when a user presses the delete key for this button.
# It constructs a [ConfirmationDialog] to make sure it isn't deleted accidentally.
func _on_delete_button_pressed() -> void:
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Do you really want to delete this button?"
	add_child(confirm_dialog)
	confirm_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	confirm_dialog.show()
	confirm_dialog.connect("confirmed", _on_confirm_deletion)


func _on_confirm_deletion() -> void:
	PopupManager.close_popup()
	var macroboard: Macroboard = get_macroboard()

	macroboard.call_deferred("delete_button", self)


class ActionsEditor extends VBoxContainer:
	signal new_action_requested

	var _scroll_container: ScrollContainer = ScrollContainer.new()
	var _reorder_vbox: ReorderableVBox = ReorderableVBox.new()
	var _add_button: Button = Button.new()


	func _init() -> void:
		set("theme_override_constants/separation", 10)

		_reorder_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll_container.add_child(_reorder_vbox)

		_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(_scroll_container)

		_add_button.text = "+"
		_add_button.connect("pressed", _on_add_button_pressed)
		add_child(_add_button)


	func add_action(action_def: PluginCoordinator.PluginActionDefinition, args_values: Array[Variant] = [], blocking: bool = false) -> void:
		var action_editor: ActionEditor = ActionEditor.new(action_def.args.generate_editor())
		action_editor.args_editor.set_values(args_values)
		action_editor.plugin = action_def.plugin
		action_editor.controller = action_def.controller
		action_editor.func_name = action_def.func_name
		action_editor.blocking = blocking
		_reorder_vbox.add_child(action_editor)


	func populate_actions(actions: Array[PluginCoordinator.PluginAction]) -> void:
		for child in _reorder_vbox.get_children():
			child.queue_free()

		var action_definitions = PluginCoordinator.get_plugin_actions()
		for action in actions:
			for action_definition in action_definitions:
				if action_definition.plugin == action.plugin and action_definition.func_name == action.func_name:
					add_action(action_definition, action.args, action.blocking)
					break


	func deserialize() -> Array[PluginCoordinator.PluginAction]:
		var ret_array: Array[PluginCoordinator.PluginAction] = []
		for child in _reorder_vbox.get_children():
			assert(child is ActionEditor)
			ret_array.append(child.to_action())

		return ret_array


	func _on_add_button_pressed() -> void:
		new_action_requested.emit()


class ActionEditor extends HBoxContainer:
	var args_editor: Config.ConfigEditor
	var plugin: String
	var controller: String
	var func_name: String
	var blocking: bool:
		set = set_blocking

	var _reorder_icon: TextureRect = TextureRect.new()
	var _reorder_icon_png: CompressedTexture2D = preload("res://resources/icons/hamburger_menu.png")
	var _editor_vbox: VBoxContainer = VBoxContainer.new()
	var _blocking_editor: Config.BoolEditor
	var _delete_button: Button = Button.new()


	func _init(editor: Config.ConfigEditor) -> void:
		set("theme_override_constants/separation", 10)

		_reorder_icon.texture = _reorder_icon_png
		_reorder_icon.custom_minimum_size = Vector2(20, 0)
		_reorder_icon.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
		_reorder_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(_reorder_icon)

		_editor_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(_editor_vbox)

		args_editor = editor
		args_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Set mouse filter so reorder dragging only works on _reorder_icon
		args_editor.mouse_filter = Control.MOUSE_FILTER_STOP
		_editor_vbox.add_child(args_editor)

		_blocking_editor = Config.BoolEditor.new(Config.BoolObject.new("Wait to finish", "blocking", false))
		_editor_vbox.add_child(_blocking_editor)

		_delete_button.text = "X"
		_delete_button.connect("pressed", _on_delete_button_pressed)
		add_child(_delete_button)


	func _ready() -> void:
		# Special cases
		if plugin == "DreamDeck" and func_name == "wait_time":
			_blocking_editor.queue_free()
			_blocking_editor = null


	func to_action() -> PluginCoordinator.PluginAction:
		var action: PluginCoordinator.PluginAction = PluginCoordinator.PluginAction.new()
		action.plugin = plugin
		action.controller = controller
		action.func_name = func_name
		action.blocking = _blocking_editor.get_value() if _blocking_editor else true
		action.args = args_editor.get_values()

		return action


	func set_blocking(value: bool) -> void:
		blocking = value
		_blocking_editor.set_value(value)


	func _on_delete_button_pressed() -> void:
		self.queue_free()
