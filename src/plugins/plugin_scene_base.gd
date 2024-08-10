class_name PluginSceneBase
extends Control
## The base for a plugin scene
##
## A plugin scene is a node that can get added by the user as panel to the layout.[br]
## Example usage:
##
## [codeblock]
## extends PluginSceneBase
##
##
## func _init() -> void:
##     config.add_bool("Your config setting", false)
##
## ...
## [/codeblock]
##
## If you want to do additional custom things you can overwrite the functions.

## The config dir for this scene. If you also need to store additional info, beyond [member config]
## please do so in this directory.
var conf_dir: String

## The config for the scene.
var config: Config = Config.new()

# The unique id of the scene.
var _scene_uuid: String


func _ready():
	handle_config()


## Called by the plugin loader when being initialized.
func init(init_scene_id: String):
	GlobalSignals.connect("entered_edit_mode", _on_entered_edit_mode)
	GlobalSignals.connect("exited_edit_mode", _on_exited_edit_mode)

	_scene_uuid = init_scene_id
	conf_dir = PluginCoordinator.get_conf_dir(_scene_uuid)
	_init_config()


## Loads [member config] from disk.
func _init_config():
	if config.get_objects().size() <= 0:
		return

	config.set_config_path(conf_dir + "config.json")
	config.load_config()
	config.connect("config_changed", _on_config_changed)


## Overwrite this function and handle your data e.g.
## [codeblock]
## func handle_config():
##    var data: Dictionary = config.get_as_dict()
##
##    setting1 = data["setting1"]
##    setting2 = data["setting2"]
## [/codeblock]
func handle_config():
	pass


## Called when edit mode is entered.
func _on_entered_edit_mode():
	pass


## Called when edit mode is exited.
func _on_exited_edit_mode():
	pass


## Called when user applied changes to the config.
func _on_config_changed():
	handle_config()


## Called when the plugin's config is to be edited.
## If you require a custom editor for your config overwrite this function.
func edit_config():
	if Config:
		return config.generate_editor()

	return null


## Called when the scene gets shown again after it was hidden.
## Note: It doesn't get called when the scene is the default scene
## and shown from app start. So e.g. background status updates should already be
## set up without this method.
## [codeblock]
## func scene_show():
##     super()
##     # disable background checks
##     set_process(true)
## [/codeblock]
func scene_show():
	self.visible = true


## Called when the scene gets hidden.
## If you e.g. do background status updates you should probably overwrite this function
## and disable them until [method scene_show] is called again.
## [codeblock]
## func scene_hide():
##     super()
##     # disable background checks
##     set_process(false)
## [/codeblock]
func scene_hide():
	self.visible = false


## Called when the scene gets deleted.
func delete_config():
	var files: Array = ConfLib.list_files_in_dir(conf_dir)
	files.append(conf_dir)
	for file in files:
		var error: Error = DirAccess.remove_absolute(file)
		if error != OK:
			push_error("Failed to delete ", file, ": ", error)
