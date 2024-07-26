class_name LayoutPanel
extends Control

var plugin: String
var scene: String
var uuid: String
var panel_name: String

var _plugin_instance: PluginSceneBase:
	get = get_plugin_instance


func _ready():
	add_to_group("layout_panels")


# scene_dict is e.g. {"scene_name": resource}
## If [param plugin_name] matches [member plugin] and [param scene_dict]
## contains the [member scene] as a key, the scene will be added.
func add_plugin_scene(plugin_name: String, scene_dict: Dictionary):
	if _plugin_instance or not plugin == plugin_name:
		return

	if scene_dict.keys()[0] == scene:
		_plugin_instance = scene_dict.values()[0].instantiate()
		_plugin_instance.init(uuid)
		$MarginContainer.add_child(_plugin_instance)

		custom_minimum_size = _plugin_instance.custom_minimum_size
		# Min x should be at least 200 otherwise things like the tabbar in edit mode
		# become basically unusable
		if custom_minimum_size.x < 200:
			custom_minimum_size.x = 200


## If [param plugin_name] and [param scene_name] match with
## [member plugin] and [member scene] respectively the current scene is freed.
func remove_plugin_scene(plugin_name: String, scene_name: String):
	if plugin == plugin_name and scene == scene_name and _plugin_instance:
		_plugin_instance.queue_free()


func serialize() -> Dictionary:
	return {"Plugin": plugin, "Scene": scene, "UUID": uuid, "Panel Name": panel_name}


func deserialize(config: Dictionary):
	uuid = config["UUID"]
	name = uuid
	scene = config["Scene"]
	plugin = config["Plugin"]
	panel_name = config["Panel Name"]

	load_scene()


## If the panel doesn't currently have it's scene instantiated this function
## instructs `PluginCoordinator` to load the scene, which triggers [method add_plugin_scene].
## This can also be used at any time if the panel doesn't have it's scene, because
## of e.g. a not activated plugin.
func load_scene():
	if not _plugin_instance:
		PluginCoordinator.load_plugin_scene(plugin, scene)


func get_plugin_instance():
	return _plugin_instance


## Function called when a user presses the delete key in edit mode for this panel.
## It constructs a [ConfirmationDialog] to make sure it isn't deleted accidentally.
func request_deletion():
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Do you really want to delete " + panel_name + "?"
	add_child(confirm_dialog)
	confirm_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	confirm_dialog.show()
	confirm_dialog.connect("confirmed", _on_confirm_deletion)


func _on_confirm_deletion():
	_plugin_instance.delete_config()
	get_node("/root/Main/Layout").call_deferred("delete_panel", self)
