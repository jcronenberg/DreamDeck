class_name MacroActionButton
extends MacroButtonBase

var _button_label: String
var _icon_path: String
var _show_button_label: bool = false
var _actions: Array[PluginCoordinator.PluginAction]
var _dragging: bool = false # If button is currently being dragged


func _ready() -> void:
	# Required for dragging to work
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Anchors the button in the center, also needed for dragging (centers the preview)
	anchors_preset = 8
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -size.x / 2
	offset_top = -size.y / 2
	offset_right = size.x / 2
	offset_bottom = size.y / 2

	apply_change()


func deserialize(dict: Dictionary) -> void:
	# Migration for old command format
	if dict.has("command"):
		_action_config_migration(dict)
		return

	_config.apply_dict(dict)
	_button_label = dict["Button label"]
	_icon_path = dict["Icon path"]
	_show_button_label = dict["Show button label"]
	if dict.has("actions"):
		_actions = []
		var dict_actions: Array = dict["actions"]
		for action_dict in dict_actions:
			var action: PluginCoordinator.PluginAction = PluginCoordinator.PluginAction.new()
			action.deserialize(action_dict)
			_actions.append(action)


func serialize() -> Dictionary:
	var serialized_actions: Array[Dictionary] = []
	for action in _actions:
		serialized_actions.append(action.serialize())

	var config_dict: Dictionary = _config.get_as_dict()
	config_dict["actions"] = serialized_actions
	return config_dict


func apply_change() -> void:
	if _icon_path:
		set_image()
	elif _button_label:
		text = _button_label

	if _show_button_label:
		show_name_with_icon()
	else:
		show_only_icon()


func set_image() -> void:
	if _icon_path:
		var complete_icon_path: String = ConfigLoader.get_conf_dir() + "icons/" + _icon_path
		var image: Image = Image.load_from_file(complete_icon_path)
		$Icon.texture = ImageTexture.create_from_image(image)


func show_only_icon() -> void:
	$Icon.offset_bottom = -20
	$Icon.offset_left = 20
	$Icon.offset_right = -20
	$AppName.visible = false
	$AppName.set_autowrap_mode(true)


func show_name_with_icon() -> void:
	$Icon.offset_bottom = -50
	$Icon.offset_left = 35
	$Icon.offset_right = -35
	$AppName.text = _button_label
	$AppName.visible = true


# FIXME delete in the future
func _action_config_migration(dict: Dictionary) -> void:
	if dict["ssh_client"] != "":
		var action: PluginCoordinator.PluginAction = PluginCoordinator.PluginAction.new()
		action.deserialize({"controller": "SSHController", "plugin": "SSH", "func_name": "exec_on_client", "args": [dict["ssh_client"], dict["command"]], "blocking": false})
		_actions = [action]
	else:
		var action: PluginCoordinator.PluginAction = PluginCoordinator.PluginAction.new()
		action.deserialize({"controller": "", "plugin": "DreamDeck", "func_name": "exec_cmd", "args": [dict["command"]], "blocking": false})
		_actions = [action]

	_config.apply_dict({"Button label": dict["app_name"], "Icon path": dict["icon_path"], "Show button label": dict["show_app_name"]})
	_button_label = dict["app_name"]
	_icon_path = dict["icon_path"]
	_show_button_label = dict["show_app_name"]


func _on_popup_confirmed(popup_window: Control) -> void:
	super(popup_window)
	if popup_window is PluginCoordinator.PluginActionSelector:
		return

	_actions = _actions_editor.deserialize()
	_config_editor.apply()
	deserialize(_config.get_as_dict())
	apply_change()


func _on_pressed() -> void:
	# If not in edit mode execute all actions
	if not GlobalSignals.get_edit_state():
		for action in _actions:
			await action.execute()
		return

	open_editor()
	_actions_editor.populate_actions(_actions)


# Handles if drag was successful or not
func _notification(notif: int) -> void:
	if not _dragging:
		return
	# Drag failed
	if notif == NOTIFICATION_DRAG_END and not get_viewport().gui_is_drag_successful():
		visible = true
		_dragging = false
		# Drag successful
	elif notif == NOTIFICATION_DRAG_END:
		_dragging = false


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not GlobalSignals.get_edit_state():
		return

	var preview: Control = Control.new()
	preview.add_child(self.duplicate())

	var data: Dictionary = {"ref": self, "type": "macroboard_button"}

	set_drag_preview(preview)
	visible = false
	_dragging = true

	return data
