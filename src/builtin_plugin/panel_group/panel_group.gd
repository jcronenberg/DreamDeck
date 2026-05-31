## Plugin scene for the panel group
class_name PanelGroup
extends PluginSceneBase

@onready var _layout: GroupLayout = %GroupLayout


func _ready() -> void:
	super()
	_layout.conf_path = conf_dir.path_join("layout.json")
	_layout.load()


func scene_show() -> void:
	super()
	for child in _layout.get_children():
		if child is LayoutPanel and child.get_plugin_instance():
			if child.visible:
				child.get_plugin_instance().scene_show()
			else:
				child.get_plugin_instance().scene_hide()


func scene_hide() -> void:
	super()
	for child in _layout.get_children():
		if child is LayoutPanel and child.get_plugin_instance():
			child.get_plugin_instance().scene_hide()


func get_nested_layout() -> GroupLayout:
	return _layout


func delete_config() -> void:
	_layout.cleanup_panels()
	super()
