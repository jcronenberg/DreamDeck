extends Control

onready var worker_thread = Thread.new()
var download_dir_path = OS.get_user_data_dir() + "/cache"
var script_res_path = "res://custom_resources/sp"
var script_user_path = OS.get_user_data_dir() + "/scripts/sp"
var script_dir_path = OS.get_user_data_dir() + "/scripts"
const metadata_refresh = 0.95 # state_refresh needs to be not evenly divisible by this
const state_refresh = 5.0
var metadata_delta := 0.0
var state_delta := 5.0 # so we instantly try get state
var metadata
var album
var artist
var track_name
var art_url
var script_path
const repeat_modes = [
	"None",
	"Playlist",
	"Track"
	]
var repeat_textures = [
	load("res://resources/repeat.tres"),
	load("res://resources/repeat_selected.tres"),
	load("res://resources/repeat_1_selected.tres")
]

# State vars
var repeat_state: int = 0
var play_state: bool = false
var shuffle_state: bool = false
var volume_state: float = 0.0

onready var config_loader = get_node("/root/ConfigLoader")

func _ready():
	# Ensure prerequisites exist
	ensure_dir_exists(download_dir_path)
	ensure_script_exists()

	# Load config
	var config_data = config_loader.get_config_data()
	if config_data.has("spotify_panel"):
		if config_data["spotify_panel"].has("disabled"):
			if config_data["spotify_panel"]["disabled"]:
				queue_free()

	# Clear cache dir to not fill the user dir with endless albumarts
	clear_cache()

func _physics_process(delta):
	metadata_delta += delta
	state_delta += delta
	if (state_delta >= state_refresh):
		state_delta = 0.0
		if worker_thread.is_active() and not worker_thread.is_alive():
			worker_thread.wait_to_finish()
		if not worker_thread.is_active():
			worker_thread.start(self, "get_state")
	if (metadata_delta >= metadata_refresh):
		if worker_thread.is_active() and not worker_thread.is_alive():
			worker_thread.wait_to_finish()
		if not worker_thread.is_active():
			worker_thread.start(self, "get_metadata")
		metadata_delta = 0.0

func execute_sp_command(command: PoolStringArray):
	var args = [script_user_path]
	for c in command:
		args.append(c)
	var output = []
	if OS.execute("bash", args, true, output):
		push_warning("failed to execute \"sp " + command[0] + "\"")

	return output[0]

func get_state():
	get_metadata()
	repeat_state = repeat_modes.find(execute_sp_command(["getloop"]).strip_edges(true, true))
	play_state = true if execute_sp_command(["getplay"]).strip_edges(true, true) == "Playing" else false
	shuffle_state = true if execute_sp_command(["getshuffle"]).strip_edges(true, true) == "true" else false
	volume_state = float(execute_sp_command(["getvolume"]))

	set_state()

func set_state():
	$Background/Controls/PlayPauseButton.pressed = play_state
	$Background/Controls/ShuffleButton.pressed = shuffle_state
	$Background/Controls/RepeatButton.texture_normal = repeat_textures[repeat_state]

func get_metadata():
	var output = execute_sp_command(["metadata"])
	if metadata != output:
		set_metadata(output)

func set_metadata(new_metadata):
	metadata = new_metadata

	var tmp

	tmp = metadata.right(metadata.find("album|") + 6)
	album = tmp.left(tmp.find("\n"))
	$Background/AlbumName.text = album

	tmp = metadata.right(metadata.find("albumArtist|") + 12)
	artist = tmp.left(tmp.find("\n"))
	$Background/ArtistsName.text = artist

	tmp = metadata.right(metadata.find("title|") + 6)
	track_name = tmp.left(tmp.find("\n"))
	$Background/TrackName.text = track_name

	tmp = metadata.right(metadata.find("artUrl|") + 7)
	tmp = tmp.left(tmp.find("\n"))
	# Only set art_url if it isn't the same
	if art_url != tmp:
		art_url = tmp
		download_cover()

func download_cover():
	var filename = art_url.right(art_url.find_last("/") + 1) + ".jpeg"
	var args: PoolStringArray = ["-O", download_dir_path + "/" + filename]
	args.insert(0, art_url)
	if OS.execute("wget", args):
		push_warning("Failed to download cover")
		return
	change_cover(filename)

func create_texture_from_image(image_path):
	var image = Image.new()
	image.load(image_path)
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	return texture

func change_cover(filename):
	var complete_cover_path = "user://cache/" + filename
	$Background/AlbumArt.texture = create_texture_from_image(complete_cover_path)

func ensure_dir_exists(path):
	var dir = Directory.new()
	if dir.open(path) != OK:
		if dir.make_dir(path) != OK:
			push_warning("Couldn't create " + path + " dir")

func check_file_exists(path) -> bool:
	var dir = Directory.new()
	if dir.file_exists(path):
		return true
	return false

func ensure_script_exists():
	ensure_dir_exists(script_dir_path)
	if not check_file_exists(script_user_path):
		var res_f = File.new()
		var user_f = File.new()
		res_f.open(script_res_path, File.READ)
		user_f.open(script_user_path, File.WRITE)
		user_f.store_buffer(res_f.get_buffer(res_f.get_len()))

func clear_cache():
	var dir = Directory.new()
	if dir.open(download_dir_path) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
	else:
		push_warning("An error occurred when trying to access the path.")


func _on_PlayPauseButton_pressed():
	execute_sp_command(["play"])


func _on_SkipBackButton_pressed():
	execute_sp_command(["prev"])


func _on_SkipForwardButton_pressed():
	execute_sp_command(["next"])


func _on_RepeatButton_pressed():
	repeat_state += 1
	if repeat_state >= len(repeat_modes):
		repeat_state = 0
	$Background/Controls/RepeatButton.texture_normal = repeat_textures[repeat_state]
	execute_sp_command(["setloop", repeat_modes[repeat_state]])


func _on_ShuffleButton_pressed():
	shuffle_state = !shuffle_state
	execute_sp_command(["setshuffle", str(shuffle_state).to_lower()])


func _on_VolumeDownButton_pressed():
	execute_sp_command(["setrelvolume", "-5"])


func _on_VolumeUpButton_pressed():
	execute_sp_command(["setrelvolume", "+5"])
