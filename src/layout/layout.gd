class_name Layout
extends DockableContainer

@onready var _conf_dir: String = PluginCoordinator.get_conf_dir("")
const SAVE_FILENAME = "layout.json"

var _new_panel_leaf: DockableLayoutPanel

const _layout_panel = preload("res://src/layout/layout_panel.tscn")


func _ready():
	super()

	if not load_layout():
		get_tree().quit(1)

	set_split_handles_visibility(false)

	PluginCoordinator.set_layout_setup_finished(true)

	GlobalSignals.connect("exited_edit_mode", _on_edit_mode_exited)
	GlobalSignals.connect("entered_edit_mode", _on_edit_mode_entered)


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
	elif typeof(config) != TYPE_DICTIONARY:
		push_error("Failed to parse %s: Wrong type" % _conf_path)
		return false

	# Check for invalid layout
	# We don't error out here because this can happen if e.g. the user
	# quit before adding their first panel
	if not config.has("Layout") or not config.has("Panels"):
		return true

	# If we are here we have a valid existing configuration, so we can
	# delete the first time launch helper
	get_node("/root/Main/FirstTimeLaunch").queue_free()

	# Layout setup from config
	_layout.from_dict(config["Layout"])
	for panel in config["Panels"]:
		var panel_instance: LayoutPanel = _layout_panel.instantiate()
		panel_instance.deserialize(panel)
		add_child(panel_instance)

	return true


func add_panel(panel_config: Dictionary):
	# When the first panel gets added here we can delete the first time launch helper
	if get_node_or_null("/root/Main/FirstTimeLaunch"):
		get_node("/root/Main/FirstTimeLaunch").queue_free()

	var panel_instance: LayoutPanel = _layout_panel.instantiate()
	add_child(panel_instance)
	panel_instance.deserialize(panel_config)
	if _new_panel_leaf:
		layout.move_node_to_leaf(panel_instance, _new_panel_leaf, _new_panel_leaf.get_names().size())

	save()


func delete_panel(panel: LayoutPanel):
	panel.free()
	save()


func set_new_panel_leaf(leaf: DockableLayoutPanel):
	_new_panel_leaf = leaf


func set_split_handles_visibility(visibility: bool):
	_split_container.visible = visibility


func _on_edit_mode_entered():
	self.tabs_visible = true
	set_split_handles_visibility(true)


func _on_edit_mode_exited():
	self.tabs_visible = false
	set_split_handles_visibility(false)
	save()
