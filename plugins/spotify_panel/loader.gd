extends Node

var loaded := false
const scene := "res://plugins/spotify_panel/scenes/spotify_panel.tscn"


func plugin_load():
	if not loaded:
		ResourceLoader.load_threaded_request(scene)
		set_process(true)


func plugin_unload():
	if loaded:
		get_node("/root/Main/VSeparator/ElementSeparator/SpotifyMargin").queue_free()
		loaded = false


func _process(_delta):
	var load_status = ResourceLoader.load_threaded_get_status(scene)
	if load_status == ResourceLoader.THREAD_LOAD_LOADED:
		add_scene(ResourceLoader.load_threaded_get(scene))
	elif load_status == ResourceLoader.THREAD_LOAD_FAILED:
		push_error("Error loading SpotifyPanel")


func add_scene(resource):
	get_node("/root/Main/VSeparator/ElementSeparator").add_child(
		resource.instantiate()
		)
	loaded = true
