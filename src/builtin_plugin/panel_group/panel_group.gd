## Plugin scene for the panel group
class_name PanelGroup
extends PluginSceneBase

@onready var _layout: GroupLayout = %GroupLayout


func _ready() -> void:
	super()
	_layout.conf_path = conf_dir.path_join("layout.json")
	_layout.load()


func get_nested_layout() -> GroupLayout:
	return _layout


func delete_config() -> void:
	_layout.cleanup_panels()
	super()
