class_name PluginLoaderBase
extends Node
## The default plugin loader.
##
## It loads [member scene] asynchronously and
## adds it to the scene tree (FIXME currently hardcoded to [member parent]).[br]
## Example usage:
##
## [codeblock]
## extends PluginLoader
##
## func _init():
##     plugin_name = "Touch"
##     scene = "res://plugins/touch/scenes/touch.tscn"
##     parent = "/root/Main/VSeparator/MarginContainer/ControlsSeparator"
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
## The scene your plugin wants to have loaded.[br]
## Example: [code]"res://plugins/your_plugin/scenes/default_scene.tscn"[/code]
# e.g. {"Scene1": "res://plugins/your_plugin/scene1.tscn", "Scene2": "res://plugins/your_plugin/scene2.tscn"}
@export var scenes: Dictionary
# e.g. {"Script1": "res://plugins/your_plugin/script1.gd", "Script2": "res://plugins/your_plugin/script2.gd"}
@export var scripts: Dictionary
## [b]FIXME[/b] temporary, will be removed in the future when this isn't "hardcoded" anymore.
@export var parent: String

## Stores if plugin is loaded.
# var _loaded := false
## Instance of [member scene] when loaded.
# var _instance = null
var _load_queue: Array


## Continuous checking if a scene in [member _load_queue] is loaded.
func _process(_delta):
	for load_item in _load_queue:
		var load_status = ResourceLoader.load_threaded_get_status(load_item)
		if load_status == ResourceLoader.THREAD_LOAD_LOADED:
			add_scene(load_item, ResourceLoader.load_threaded_get(load_item))
		elif load_status == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Error loading %s" % load_item)

	if len(_load_queue) == 0:
		set_process(false)


func plugin_load():
	for script in scripts:
		ResourceLoader.load_threaded_request(scripts[script])
		_load_queue.append(scripts[script])
	set_process(true)


## Function called when plugin loading is started.
## [param scene] is loaded asynchronously
## and once this is finished [method add_scene] is called.
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
func add_scene(scene: String, resource):
	if resource is GDScript:
		add_child(resource.new())
	elif resource is PackedScene:
		var scene_name = scenes.find_key(scene)
		PluginCoordinator.call_deferred("add_scene", plugin_name, {scene_name: resource})
