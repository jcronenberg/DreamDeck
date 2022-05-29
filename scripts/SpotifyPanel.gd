extends Control

onready var worker_thread = Thread.new()
var download_dir_path = OS.get_user_data_dir() + "/cache"
const refresh_timer = 0.5
var cum_delta = 0.0
var metadata
var album
var artist
var track_name
var art_url
var script_path

onready var config_loader = get_node("/root/ConfigLoader")

func _ready():
	var config_data = config_loader.get_config_data()
	if config_data.has("spotify_panel"):
		if config_data["spotify_panel"].has("disabled"):
			if config_data["spotify_panel"]["disabled"]:
				queue_free()
		if config_data["spotify_panel"].has("script_path"):
			script_path = config_data["spotify_panel"]["script_path"]
		else:
			push_error("Spotify_panel script_path not set in config, disabling the panel")
			queue_free()

	ensure_download_dir_exists()
	clear_cache()
	#download_cover("https://i.scdn.co/image/ab67616d0000b273e46a98f61e0510d50a51898f")
	#get_metadata()

func _physics_process(delta):
	cum_delta += delta
	if (cum_delta <= refresh_timer):
		return
	if worker_thread.is_active() and not worker_thread.is_alive():
		worker_thread.wait_to_finish()
	if not worker_thread.is_active():
		worker_thread.start(self, "get_metadata")
	cum_delta = 0.0

func get_metadata():
	var args = ["metadata"]
	var output = []
	if OS.execute("/home/jorik/bin/sp", args, true, output):
		print("Couldn't get spotify metadata")
		return

	if metadata != output[0]:
		set_metadata(output[0])

func set_metadata(new_metadata):
	metadata = new_metadata
	var tmp
	tmp = metadata.right(metadata.find("album|") + 6)
	album = tmp.left(tmp.find("\n"))
	$Background/AlbumName.text = album
	#print("album: " + album)
	tmp = metadata.right(metadata.find("albumArtist|") + 12)
	artist = tmp.left(tmp.find("\n"))
	$Background/ArtistsName.text = artist
	#print("artist: " + artist)
	tmp = metadata.right(metadata.find("title|") + 6)
	track_name = tmp.left(tmp.find("\n"))
	$Background/TrackName.text = track_name
	#print("track_name: " + track_name)
	tmp = metadata.right(metadata.find("artUrl|") + 7)
	tmp = tmp.left(tmp.find("\n"))
	if art_url != tmp:
		art_url = tmp
		#print("art_url: " + art_url)
		download_cover()

func download_cover():
	var filename = art_url.right(art_url.find_last("/") + 1) + ".jpeg"
	var args: PoolStringArray = ["-O", download_dir_path + "/" + filename]
	args.insert(0, art_url)
	if OS.execute("wget", args):
		print("Failed to download cover")
		return
	change_cover(filename)

func change_cover(filename):
	var complete_cover_path = "user://cache/" + filename
	var image = Image.new()
	image.load(complete_cover_path)
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	$Background/AlbumArt.texture = texture

func ensure_download_dir_exists():
	var dir = Directory.new()
	if dir.open(download_dir_path) != OK:
		if dir.make_dir(download_dir_path) != OK:
			print("Couldn't create cache dir")

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
		print("An error occurred when trying to access the path.")
