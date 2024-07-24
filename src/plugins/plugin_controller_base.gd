class_name PluginControllerBase
extends Node

## The config dir for this controller. If you also need to store additional info, beyond [member config]
## please do so in this directory.
var conf_dir: String

## The config for the controller.
## Requires setting [member config_proto] to work by default.
var config: Config

## The [class Dictionary] from which [member config] gets created.[br]
## Look at [class Config] for the info what this is supposed to look like.
## Not setting this disables the default [member config] initialization.
var config_proto: Array[Dictionary]

## The name of the plugin. This used as the name of the directory where [member config] is saved.
var plugin_name: String


## Called by PluginCoordinator when being initialized.
func init():
	conf_dir = PluginCoordinator.get_conf_dir(plugin_name.to_snake_case())
	_init_config()


func _ready():
	handle_config()


## Initializes [member config] and loads it from disk.
func _init_config():
	if not config_proto:
		return

	config = Config.new(config_proto, conf_dir + "config.json")
	config.load_config()
	config.connect("config_changed", _on_config_changed)


## Overwrite this function and handle your data e.g.
## [codeblock]
## func handle_config():
##    var data = config.get_as_dict()
##
##    setting1 = data["setting1"]
##    setting2 = data["setting2"]
## [/codeblock]
func handle_config():
	pass


## Called when user applied changes to the config.
func _on_config_changed():
	handle_config()


## Called when the plugin's config is to be edited.
## If you require a custom editor for your config overwrite this function.
func edit_config():
	return config.generate_editor()
