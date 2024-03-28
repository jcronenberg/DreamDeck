class_name LayoutPanel
extends Control


var plugin: String
var scene: String
var uuid: String
var panel_name: String

# TODO type to PluginSceneBase?
var _plugin_instance


func _ready():
	add_to_group("layout_panels")


# scene_dict is {"scene_name": resource}
func add_plugin_scene(plugin_name: String, scene_dict: Dictionary):
	if $MarginContainer.get_child_count() > 0 or not plugin == plugin_name:
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


func serialize() -> Dictionary:
	return {"Plugin": plugin, "Scene": scene, "UUID": uuid, "Panel Name": panel_name}


func deserialize(config: Dictionary):
	uuid = config["UUID"]
	name = uuid
	scene = config["Scene"]
	plugin = config["Plugin"]
	panel_name = config["Panel Name"]

	PluginCoordinator.load_plugin_scene(plugin, scene)


func get_plugin_instance():
	return _plugin_instance


func request_deletion():
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Do you really want to delete " + panel_name + "?"
	add_child(confirm_dialog)
	confirm_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	confirm_dialog.show()
	confirm_dialog.connect("confirmed", _on_confirm_deletion)


func _on_confirm_deletion():
	queue_free()
