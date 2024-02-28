class_name PluginLoader
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
## The scene your plugin wants to have loaded.
@export var scene: String
## [b]FIXME[/b] temporary, will be removed in the future when this isn't "hardcoded" anymore.
@export var parent: String

## Stores if plugin is loaded
var _loaded := false
## Instance of [member scene] when loaded
var _instance = null


## Continuous checking if [member scene] is loaded.
func _process(_delta):
	var load_status = ResourceLoader.load_threaded_get_status(scene)
	if load_status == ResourceLoader.THREAD_LOAD_LOADED:
		add_scene(ResourceLoader.load_threaded_get(scene))
	elif load_status == ResourceLoader.THREAD_LOAD_FAILED:
		push_error("Error loading %s" % plugin_name)


## Function called when plugin loading is started.
## [member scene] is loaded asynchronously
## and once this is finished [method add_scene] is called.
func plugin_load():
	if not allow_os.is_empty() and not allow_os.has(OS.get_name()):
		push_error("%s doesn't allow OS: %s" % [plugin_name, OS.get_name()])
		return
	if not _loaded:
		ResourceLoader.load_threaded_request(scene)
		set_process(true)


## Function called when plugin is being unloaded.[br]
## Note: doesn't get called when quitting DreamDeck,
## just when unload while running happens
func plugin_unload():
	if _loaded:
		_instance.queue_free()
		_loaded = false


## Function called when asynchronous loading of [member scene] is finished
func add_scene(resource):
	if resource is GDScript:
		_instance = resource.new()
	elif resource is PackedScene:
		_instance = resource.instantiate()

	if parent.is_empty():
		add_child(_instance)
	else:
		get_node(parent).add_child(_instance)
	_loaded = true
