class_name Layout
extends DockableContainer

@onready var _conf_dir: String = PluginCoordinator.get_conf_dir("")
const SAVE_FILENAME = "layout.json"

var _new_panel_leaf: DockableLayoutPanel

const _layout_panel = preload("res://src/layout/layout_panel.tscn")


func _ready():
	super()
	load_layout()
	# TODO is this necessary?
	PluginCoordinator.set_layout_setup_finished(true)
	GlobalSignals.connect("exited_edit_mode", _on_edit_mode_exited)
	GlobalSignals.connect("entered_edit_mode", _on_edit_mode_entered)


func save():
	var save_file = FileAccess.open(_conf_dir + SAVE_FILENAME, FileAccess.WRITE)
	if not save_file:
		push_error(FileAccess.get_open_error())
		return

	save_file.store_string(JSON.stringify(serialize(), "\t"))


func serialize() -> Dictionary:
	var panels: Array[Dictionary] = []
	for child in get_children():
		if child is LayoutPanel:
			panels.append(child.serialize())
	return {"Layout": layout.to_dict(), "Panels": panels}


func load_layout():
	var save_file = FileAccess.open(_conf_dir + SAVE_FILENAME, FileAccess.READ)
	if not save_file:
		push_error(FileAccess.get_open_error())
		return

	var json = JSON.new()
	var error = json.parse(save_file.get_as_text())
	if error != OK:
		push_error("JSON Parse Error: ", json.get_error_message())
		return

	var config = json.data
	_layout.from_dict(config["Layout"])
	for panel in config["Panels"]:
		var panel_instance: LayoutPanel = _layout_panel.instantiate()
		panel_instance.deserialize(panel)
		add_child(panel_instance)


func add_panel(panel_config: Dictionary):
	var panel_instance: LayoutPanel = _layout_panel.instantiate()
	add_child(panel_instance)
	panel_instance.deserialize(panel_config)
	layout.move_node_to_leaf(panel_instance, _new_panel_leaf, _new_panel_leaf.get_names().size())

	save()


func set_new_panel_leaf(leaf: DockableLayoutPanel):
	_new_panel_leaf = leaf


func _on_edit_mode_entered():
	self.tabs_visible = true


func _on_edit_mode_exited():
	self.tabs_visible = false
	save()
