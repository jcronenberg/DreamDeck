class_name Layout
extends DockableContainer

const SAVE_FILENAME = "layout.json"
const LAYOUT_PANEL = preload("res://src/layout/layout_panel.tscn")

const SPLIT_HANDLE_MODULATE := Color(8.0, 8.0, 8.0, 1.0)

var _new_panel_leaf: DockableLayoutPanel:  # Parent for new panel
	set = set_new_panel_leaf
@onready var _conf_path: String = PluginCoordinator.get_conf_dir("").path_join(SAVE_FILENAME)


func _ready():
	super()

	_split_container.modulate = SPLIT_HANDLE_MODULATE

	if not load_layout():
		push_error("Failed to load layout")
		get_tree().quit(1)

	set_split_handles_visibility(false)

	PluginCoordinator.set_layout_setup_finished(true)
	PluginCoordinator.layout = self

	GlobalSignals.connect("exited_edit_mode", _on_edit_mode_exited)
	GlobalSignals.connect("entered_edit_mode", _on_edit_mode_entered)
	GlobalSignals.connect("exited_resize_mode", _on_resize_mode_exited)
	GlobalSignals.connect("entered_resize_mode", _on_resize_mode_entered)

	ConfigLoader.config.config_changed.connect(_apply_sidebar_inset)
	GlobalSignals.sidebar_visibility_changed.connect(_apply_sidebar_inset)
	_apply_sidebar_inset()


## Insets this container's edges so it keeps clear of the sidebar
## (see the global "Sidebar position"/"Sidebar thickness" settings).
## While the sidebar is hidden the container spans the full window.
func _apply_sidebar_inset() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not GlobalSignals.sidebar_visible:
		return
	var data: Dictionary = ConfigLoader.get_config()
	var thickness: float = data["sidebar_thickness"]
	match data["sidebar_position"]:
		Sidebar.SidebarPosition.LEFT:
			offset_left = thickness
		Sidebar.SidebarPosition.RIGHT:
			offset_right = -thickness
		Sidebar.SidebarPosition.TOP:
			offset_top = thickness
		Sidebar.SidebarPosition.BOTTOM:
			offset_bottom = -thickness


func save():
	ConfLib.save_config(_conf_path, serialize())


func serialize() -> Dictionary:
	var panels: Array[Dictionary] = []
	for child in get_children():
		if child is LayoutPanel:
			panels.append(child.serialize())
	return {"Layout": layout.to_dict(), "Panels": panels}


func load_layout() -> bool:
	# Just return true when config doesn't yet exist
	# as then first time launch helper does the rest
	if not FileAccess.file_exists(_conf_path):
		return true

	var config: Variant = ConfLib.load_config(_conf_path)
	if not config:
		return false
	if typeof(config) != TYPE_DICTIONARY:
		push_error("Failed to parse %s: Wrong type" % _conf_path)
		return false

	# Check for invalid layout
	# We don't error out here because this can happen if e.g. the user
	# quit before adding their first panel
	if not config.has("Layout") or not config.has("Panels"):
		return true

	# If we are here we have a valid existing configuration, so we can
	# delete the first time launch helper
	var first_time_launch: Control = get_node_or_null("/root/Main/FirstTimeLaunch")
	if first_time_launch:
		first_time_launch.queue_free()

	# Layout setup from config
	_layout.from_dict(config["Layout"])
	for panel in config["Panels"]:
		var panel_instance: LayoutPanel = LAYOUT_PANEL.instantiate()
		panel_instance.deserialize(panel)
		add_child(panel_instance)

	return true


func add_panel(panel_config: Dictionary):
	# When the first panel gets added here we can delete the first time launch helper
	if get_node_or_null("/root/Main/FirstTimeLaunch"):
		get_node("/root/Main/FirstTimeLaunch").queue_free()

	var panel_instance: LayoutPanel = LAYOUT_PANEL.instantiate()
	add_child(panel_instance)
	panel_instance.deserialize(panel_config)
	if _new_panel_leaf:
		layout.move_node_to_leaf(
			panel_instance, _new_panel_leaf, _new_panel_leaf.get_names().size()
		)

	save()
	PluginCoordinator.panels_changed.emit()


func delete_panel(panel: LayoutPanel):
	panel.free()
	PluginCoordinator.panels_changed.emit()
	save()


func set_new_panel_leaf(leaf: DockableLayoutPanel):
	_new_panel_leaf = leaf


## Get all available panel names.
func get_panel_names() -> Array[String]:
	return _collect_panel_names(self)


# Recursive function to walk panel groups and get all tab names
func _collect_panel_names(container: DockableContainer) -> Array[String]:
	var names: Array[String] = []
	for tab in container.get_tabs():
		if not tab is LayoutPanel:
			continue
		names.append(tab.panel_name)
		var plugin = tab.get_plugin_instance()
		if plugin and plugin.has_method("get_nested_layout"):
			names.append_array(_collect_panel_names(plugin.get_nested_layout()))
	return names


## Show a panel irrespective of how deep down panel groups it is.
func show_panel_by_name(panel_name: String) -> bool:
	return _activate_panel_in_container(self, panel_name)


# Recursive function to walk panel groups and activate all the tabs
# to show a specific panel
func _activate_panel_in_container(container: DockableContainer, panel_name: String) -> bool:
	for tab in container.get_tabs():
		if not tab is LayoutPanel:
			continue
		if tab.panel_name == panel_name:
			container.call_deferred("set_control_as_current_tab", tab)
			return true
		var plugin = tab.get_plugin_instance()
		if plugin and plugin.has_method("get_nested_layout"):
			if _activate_panel_in_container(plugin.get_nested_layout(), panel_name):
				container.call_deferred("set_control_as_current_tab", tab)
				return true
	return false


func _on_edit_mode_entered():
	self.tabs_visible = true
	set_split_handles_visibility(true)


func _on_edit_mode_exited():
	self.tabs_visible = false
	set_split_handles_visibility(false)
	save()


func _on_resize_mode_entered():
	set_split_handles_visibility(true)


func _on_resize_mode_exited():
	set_split_handles_visibility(false)
	save()
