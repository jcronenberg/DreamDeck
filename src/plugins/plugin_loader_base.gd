class_name PluginLoaderBase
extends Node
## The default plugin loader.
##
## Loads [member scenes] and [member controllers] asynchronously.
## The loader gets added as a child of PluginCoordinator.
## Scenes can be added by the user to their layout.
## Controllers are automatically loaded and added as a child of this loader.[br]
## Example usage:
##
## [codeblock]
## extends PluginLoaderBase
##
## func _init():
##     plugin_name = "Plugin Name"
##     scenes = {"Scene Name": "res://plugins/your_plugin/scenes/default_scene.tscn"}
##     controllers = {"PluginController": "res://plugins/your_plugin/controller.gd"}
##     allow_os = ["Linux"]
## [/codeblock]
##
## If you want to do additional custom things you can overwrite the functions:
##
## [codeblock]
## func plugin_load():
##     custom_things()
##
##     # optionally you can call the super() method
##     # to still execute the default plugin_load code
##     super()
## [/codeblock]

## OSes that your plugin supports.[br]
## See [method OS.get_name] for what the possible values to whitelist.[br]
## Empty/default allows all OSes.
@export var allow_os: Array = []

## Your plugin's name.[br]
## [b]FIXME[/b] currently not utilised.
@export var plugin_name: String

## The scenes your plugin makes available to users.[br]
## Example: [code]{"Scene Name": "res://plugins/your_plugin/scenes/default_scene.tscn"}[/code]
@export var scenes: Dictionary

## The controllers for your plugin.
## Controllers get loaded always when a plugin is active.
## They will be put into the scene tree as a child of this loader.
## If you need to access them get the loader via PluginCoordinator
## and then use [method get_controller].[br]
## Example: [code]{"PluginController": "res://plugins/your_plugin/controller.gd"}[/code]
@export var controllers: Dictionary

## The actions of your plugin.[br]
## Example:
## [codeblock]
## func _init():
##     var _arguments_config: Config = Config.new()
##     _arguments_config.add_string("Example argument 1", "example_arg1", "Default value")
##     _arguments_config.add_float("Example argument 2", "example_arg2", 2.0)
##     actions = [PluginCoordinator.PluginActionDefinition.new("Example action", "example_func", "A description of what this action does", _arguments_config, "Example plugin", "ExampleController")]
## [/codeblock]
## The action calls the function in your specified controller and the arguments will be the ones you
## specified in the [code]args_config[/code] in the order the objects were added.[br]
## So in the above case your function would have to look like this:
## [codeblock]
## func example_func(example_argument1: String, example_argument2: float) -> bool:
## [/codeblock]
## (The bool return is optional, but with it you can indicate if the action was successfully executed or not)
var actions: Array[PluginCoordinator.PluginActionDefinition] = []

## Indicates if the plugin has a global config or not.
## Determines if a "Settings" button is shown in the plugins popup.
var has_settings: bool = false

# Used to store all resources that are supposed to be loaded
var _load_queue: Array[String] = []

# Stores all controllers for better access via [method get_controller]
var _controllers: Dictionary = {}


# Continuous checking if a scene in [member _load_queue] is loaded.
func _process(_delta):
	for load_item in _load_queue:
		var load_status = ResourceLoader.load_threaded_get_status(load_item)
		if load_status == ResourceLoader.THREAD_LOAD_LOADED:
			add_resource(load_item, ResourceLoader.load_threaded_get(load_item))
		elif load_status == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Error loading %s" % load_item)

	if len(_load_queue) == 0:
		set_process(false)


## Called when the plugin is to be loaded.
## Either at startup or at runtime.
func plugin_load():
	# Threaded load all controllers
	for controller in controllers:
		ResourceLoader.load_threaded_request(controllers[controller])
		_load_queue.append(controllers[controller])
	set_process(true)


## Function called when a scene of this plugin is requested by a [LayoutPanel].
## The scene will be cached by [PluginCoordinator] and only requested once.
## [param scene] is loaded asynchronously
## and once this is finished [method add_resource] is called.
func plugin_load_scene(scene: String):
	if not allow_os.is_empty() and not allow_os.has(OS.get_name()):
		push_error("%s doesn't allow OS: %s" % [plugin_name, OS.get_name()])
		return

	if _load_queue.has(scenes[scene]):
		return
	ResourceLoader.load_threaded_request(scenes[scene])
	_load_queue.append(scenes[scene])
	set_process(true)


## Function called when plugin is being unloaded.[br]
## Note: doesn't get called when quitting DreamDeck,
## just when unload while running happens.
func plugin_unload():
	for scene in scenes:
		PluginCoordinator.call_deferred("remove_scene", plugin_name, scene)


## Function called when asynchronous loading of [param scene] is finished.
func add_resource(resource_name: String, resource):
	if resource is GDScript:
		var controller_name = controllers.find_key(resource_name)
		_controllers[controller_name] = resource.new()
		_controllers[controller_name].init()
		add_child(_controllers[controller_name])
	elif resource is PackedScene:
		var scene_name: String = scenes.find_key(resource_name)
		PluginCoordinator.call_deferred("add_scene", plugin_name, {scene_name: resource})


## If the plugin has a controller this function can be used to get a reference to it.
func get_controller(controller_name: String) -> PluginControllerBase:
	if _controllers.has(controller_name):
		return _controllers[controller_name]

	return null


## If the plugin [member has_settings] is true this function is called
## when the settings button in the plugin popup is pressed.
## The settings page needs to implement these 2 functions, to handle
## the [PopupManager]'s confirm and cancel actions.
## [codeblock]
## # Can indicate whether confirm is successful or not
## func confirm() -> bool:
## func cancel() -> void:
## [/codeblock]
func get_settings_page() -> Control:
	return null
