## Container that allows nesting panels
class_name GroupLayout
extends DockableContainer

const LAYOUT_PANEL = preload("res://src/layout/layout_panel.tscn")

var conf_path: String

var _new_panel_leaf: DockableLayoutPanel


func _ready() -> void:
	super()
	_split_container.modulate = Layout.SPLIT_HANDLE_MODULATE
	var in_edit_mode: bool = GlobalSignals.get_edit_state()
	tabs_visible = in_edit_mode
	set_split_handles_visibility(in_edit_mode or GlobalSignals.get_resize_state())
	GlobalSignals.connect("entered_edit_mode", _on_entered_edit_mode)
	GlobalSignals.connect("exited_edit_mode", _on_exited_edit_mode)
	GlobalSignals.connect("entered_resize_mode", _on_entered_resize_mode)
	GlobalSignals.connect("exited_resize_mode", _on_exited_resize_mode)


func load() -> void:
	if conf_path.is_empty() or not FileAccess.file_exists(conf_path):
		return

	var config: Variant = ConfLib.load_config(conf_path)
	if (
		not config
		or typeof(config) != TYPE_DICTIONARY
		or not config.has("Layout")
		or not config.has("Panels")
	):
		push_error("Error when reading config")
		return

	layout.from_dict(config["Layout"])
	for panel_data in config["Panels"]:
		var panel_instance: LayoutPanel = LAYOUT_PANEL.instantiate()
		add_child(panel_instance)
		panel_instance.deserialize(panel_data)

	PluginCoordinator.panels_changed.emit()


func save() -> void:
	if conf_path.is_empty():
		return

	var panels: Array[Dictionary] = []
	for child in get_children():
		if child is LayoutPanel:
			panels.append(child.serialize())
	(
		ConfLib
		. save_config(
			conf_path,
			{
				"Layout": layout.to_dict(),
				"Panels": panels,
			}
		)
	)


func add_panel(panel_config: Dictionary) -> void:
	var panel_instance: LayoutPanel = LAYOUT_PANEL.instantiate()
	add_child(panel_instance)
	panel_instance.deserialize(panel_config)
	if _new_panel_leaf:
		layout.move_node_to_leaf(
			panel_instance, _new_panel_leaf, _new_panel_leaf.get_names().size()
		)
	save()
	PluginCoordinator.panels_changed.emit()


func set_new_panel_leaf(leaf: DockableLayoutPanel) -> void:
	_new_panel_leaf = leaf


func delete_panel(panel: LayoutPanel) -> void:
	panel.free()
	save()
	PluginCoordinator.panels_changed.emit()


func cleanup_panels() -> void:
	for child in get_children():
		if child is LayoutPanel:
			var instance = child.get_plugin_instance()
			if instance and is_instance_valid(instance):
				instance.delete_config()


func _on_entered_edit_mode() -> void:
	tabs_visible = true
	set_split_handles_visibility(true)


func _on_exited_edit_mode() -> void:
	tabs_visible = false
	set_split_handles_visibility(false)
	save()


func _on_entered_resize_mode() -> void:
	set_split_handles_visibility(true)


func _on_exited_resize_mode() -> void:
	set_split_handles_visibility(false)
	save()
