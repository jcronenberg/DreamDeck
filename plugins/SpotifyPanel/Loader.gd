extends Node

var loaded := false
var loader
const TIME_MAX := 10


func load():
	if not loaded:
		loader = ResourceLoader.load_interactive("res://plugins/SpotifyPanel/scenes/SpotifyPanel.tscn")
		set_process(true)


func unload():
	if loaded:
		get_node("/root/Main/VSeparator/ElementSeparator/SpotifyMargin").queue_free()
		loaded = false


func _process(_delta):
	if loader == null:
		# no need to process anymore
		set_process(false)
		return

	var t = OS.get_ticks_msec()
	# Use "time_max" to control for how long we block this thread.
	while OS.get_ticks_msec() < t + TIME_MAX:
		# Poll your loader.
		var err = loader.poll()

		if err == ERR_FILE_EOF: # Finished loading.
			var resource = loader.get_resource()
			loader = null
			add_scene(resource)
			break
		elif err != OK:
			push_error("Error loading Touch")
			loader = null
			break


func add_scene(resource):
	get_node("/root/Main/VSeparator/ElementSeparator").add_child(
		resource.instance()
		)
	loaded = true
