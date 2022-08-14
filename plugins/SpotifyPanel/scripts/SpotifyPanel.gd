extends Control

# Plugin
const PLUGIN_NAME = "SpotifyPanel"

# Metadata refresh timer
var METADATA_REFRESH := 1.0 # state_refresh needs to be not evenly divisible by this
var metadata_delta := 1.0
# Device refresh timers
var DEVICES_REFRESH := 5.2 # TODO this is pretty ugly. Implement a queue
var devices_delta := 4.0
# Skips one metadata update, useful for e.g. play/pause button
# as if we don't skip, it can end up being updated by the metadata refresh to the wrong state
var wait_to_update: bool = false

# Repeat resources
# States
const repeat_modes = [
	"off",
	"context",
	"track"
	]
# Texture resources
var repeat_textures := [
	load("res://resources/SpotifyPanel/repeat.tres"),
	load("res://resources/SpotifyPanel/repeat_selected.tres"),
	load("res://resources/SpotifyPanel/repeat_1_selected.tres")
]

# Spotify API variables
var refresh_token: String # The token with which a new access_token can be generated
var access_token: String # The token with which the requests get made, expires after 1 hour
var client_id: String # The client_id provided by the spotify_app by the user
var client_secret: String # The secret provided by the spotify_app by the user
var encoded_client: String # Base64 encoded client_id and client_secret
var authorization_code: String # Code from callback url, used for first time authorization
const redirect_uri: String = "http://localhost:8888/callback"
const scope: String = "user-modify-playback-state user-read-playback-state user-read-currently-playing"
const base_api_url: String = "https://api.spotify.com/v1"

# State vars
# Playback
var cur_data # Current data from state requests, used to check if changes happened
var repeat_state: int = 0 # Song repeat state, value between 0 and 2, see repeat_modes
var play_state: bool = false
var shuffle_state: bool = false
var volume_state: float = 0.0
var album: String
var artist: String
var track_name: String
var art_url: String
# Devices
var cur_device_data # Current device data, used to check if changes happened
var device_list := []
var playback_active := true # This gets set to false when the api doesn't provide playback-state anymore

# Config vars
var plugin_config
var config_completed: bool = false # Stop all calls while we setup the config
var input_stage: int = 0 # At what stage the input is, since we have to ask for 3 user inputs
var input_scene

# Config stage texts
var config_stage1_text: String = "No existing configuration for the Spotify Panel found\n" \
								 + "You need to create a developer application\n" \
								 + "Instructions can be found [url=" \
								 + "https://github.com/jcronenberg/DreamDeck#connect-to-spotifys-api" \
								 + "]here[/url]\n\n" \
								 + "Enter the Client ID"
var config_stage2_text: String = "Enter the Client Secret"
func create_auth_link() -> String:
	return "https://accounts.spotify.com/authorize?client_id=" \
		+ client_id \
		+ "&response_type=code&scope=" \
		+ scope \
		+ "&redirect_uri=" \
		+ redirect_uri
func config_stage3_text() -> String:
	return "Click this [url=" \
		   + create_auth_link() \
		   + "]link[/url] and authorize your account\nThen paste the url here:"

# Nodes
onready var config_loader := get_node("/root/ConfigLoader")
onready var http_get := get_node("HTTPGet")
onready var http_post := get_node("HTTPPost")
onready var http_get_devices := get_node("HTTPGetDevices")

# Download cache
onready var cache_dir_path: String = config_loader.get_conf_dir() + "cache"


func _ready():
	# Ensure prerequisites exist
	ensure_dir_exists(cache_dir_path)

	# Load configs
	load_configs()

	# Clear cache dir to not fill the user dir with endless albumarts
	clear_cache()

	# Setup for requests
# warning-ignore:return_value_discarded
	http_get.connect("request_completed", self, "_on_get_request_completed")
# warning-ignore:return_value_discarded
	http_get_devices.connect("request_completed", self, "_on_get_request_completed")


func _physics_process(delta):
	if not config_completed:
		return
	metadata_delta += delta
	if metadata_delta >= METADATA_REFRESH:
		request_state()
		metadata_delta = 0.0
	devices_delta += delta
	if devices_delta >= DEVICES_REFRESH and access_token:
		var headers = ["Authorization: Bearer " + access_token, "Content-Type: application/json"]
		http_get_devices.request(base_api_url + "/me/player/devices", headers, true, 0, "")
		devices_delta = 0.0


# Load config from config_loader and apply the settings to local variables
func load_configs():
	# Load global config
	var config_data = config_loader.get_config_data()
	if config_data.has("spotify_panel"):
		if config_data["spotify_panel"].has("disabled"):
			if config_data["spotify_panel"]["disabled"]:
				queue_free()
		if config_data["spotify_panel"].has("legacy"):
			if config_data["spotify_panel"]["legacy"] and OS.get_name() == "X11":
				var legacy_instance = load("res://plugins/SpotifyPanelLegacy/scenes/SpotifyPanelLegacy.tscn").instance()
				get_parent().call_deferred("add_child", legacy_instance)
				queue_free()
			elif (config_data["spotify_panel"]["legacy"]):
				push_error("You have enabled the spotify legacy version on a non linux platform. This doesn't work, ignoring.")
		if config_data["spotify_panel"].has("refresh_interval"):
			METADATA_REFRESH = config_data["spotify_panel"]["refresh_interval"]
			# We don't need to refresh devices as often
			# Add + 0.1 to offset it a bit to METADATA_REFRESH
			DEVICES_REFRESH = config_data["spotify_panel"]["refresh_interval"] * 3 + 0.1

	# Load plugin config
	plugin_config = config_loader.get_plugin_config(PLUGIN_NAME)
	if plugin_config:
		refresh_token = plugin_config["refresh_token"]
		encoded_client = plugin_config["encoded_client"]
		config_completed = true
	else:
		create_config()


# Creates the first dialog and connects the functions
func create_config():
	input_scene = load("res://scenes/UserInputPopup.tscn").instance()
	get_node("/root/Main/InputCenterContainer").add_child(input_scene)
	input_scene.create_dialog(config_stage1_text, "Client ID")
	input_scene.connect("apply_text", self, "_on_text_config")
	input_scene.connect("cancelled", self, "_on_config_cancel")


# If the user prematurely cancels we delete the object
func _on_config_cancel():
	queue_free()


# User input function
# Steps through all 3 stages we need, increments input_stage
# Stage 0 Client ID
# Stage 1 Client Secret
#         After this we can create encoded_client and with that generate the url
#         for the user to authorize the app
# Stage 2 Final URL
#         User inputs the callback url they get and we can finalize the config
#         Also disconnect from user_input
func _on_text_config(text):
	# 1st state: client_id
	if input_stage == 0:
		client_id = text
		input_scene.create_dialog(config_stage2_text, "Client Secret")
		input_stage = 1
	elif input_stage == 1:
		client_secret = text
		encoded_client = Marshalls.utf8_to_base64(client_id + ":" + client_secret)
		input_scene.create_dialog(config_stage3_text(), \
								  "Url e.g. like: http://localhost:8888/callback?code=...")
		input_stage = 2
	elif input_stage == 2:
		input_scene.hide()
		input_scene.disconnect("apply_text", self, "_on_text_config")
		input_scene.disconnect("cancelled", self, "_on_config_cancel")
		finalize_config(text)


# Extracts the authorization_code from the callback url
# Then initiates a authorization request and sets config_completed
# TODO add better checks if user inputs a wrong url
func finalize_config(url):
	authorization_code = url.right(url.find("callback?code=") + 14)
	request_authorization()
	config_completed = true


# Custom sort for device_list
class DeviceSorter:
	static func sort_by_name(a, b):
		if a.name > b.name:
			return true
		return false


func generate_device_list(data):
	# Only regenerate if something changed
	if cur_device_data == data:
		return
	cur_device_data = data

	# Reset device_list
	device_list = []
	# Store currently active device to be able to select it later
	var active_device = data[0]

	# Iterate through devices in data
	for d in data:
		# Set current active device
		if d.is_active:
			active_device = d
		# Add device to device_list
		device_list.append(d)

	# Sort device_list as otherwise the order changes constantly
	device_list.sort_custom(DeviceSorter, "sort_by_name")

	# Set DeviceOptions properties
	# Clear
	$Background/Controls/DeviceOptions.clear()
	# Fill
	for i in range(device_list.size()):
		$Background/Controls/DeviceOptions.add_item(device_list[i].name, i)
	# Select current active device
	$Background/Controls/DeviceOptions.select(device_list.find(active_device))


func set_device(device, play=true):
	send_command("/me/player", 3, true, JSON.print({"device_ids":[device.id],"play":play}))


func request_authorization():
	var headers = ["Content-Type: application/x-www-form-urlencoded", \
				   "Authorization: Basic " + encoded_client]
	var data = "grant_type=authorization_code&code=" + authorization_code \
			   + "&redirect_uri=" + redirect_uri
	send_get_command("https://accounts.spotify.com/api/token", headers, 2, data)


func request_new_token():
	var headers = ["Content-Type: application/x-www-form-urlencoded", \
				   "Authorization: Basic " + encoded_client]
	var data = "grant_type=refresh_token&refresh_token=" + refresh_token
	send_get_command("https://accounts.spotify.com/api/token", headers, 2, data)


func request_state():
	# If we don't have a access token we either have to request one or just don't execute while we wait
	# for a refresh token to be generated
	if not access_token:
		if refresh_token:
			request_new_token()
		return
	var headers = ["Authorization: Bearer " + access_token, "Content-Type: application/json"]
	send_get_command(base_api_url + "/me/player", headers)


func _on_get_request_completed(_result, response_code, _headers, body):
	# response_code handling
	# Expired token
	if response_code == 401:
		request_new_token()
		return
	# This code happens when state is requested but playback is not active
	elif response_code == 204:
		playback_active = false
		return
	# Error handling/Unexpected response
	elif response_code != 200:
		if OS.has_feature("editor"):
			print("Unexpected response code: " + str(response_code))
			print("Body: " + body.get_string_from_utf8())
		return

	# body handling
	var json_result = JSON.parse(body.get_string_from_utf8()).result
	# GET /me/player result
	if json_result.has("device"):
		playback_active = true
		set_state(json_result)
	# GET /me/player/devices result
	elif json_result.has("devices"):
		generate_device_list(json_result["devices"])
	# POST /api/token authorization_code result
	# Needs to be before refresh_token result handling!
	elif json_result.has("refresh_token"):
		# Set vars
		refresh_token = json_result["refresh_token"]
		access_token = json_result["access_token"]
		# Add to plugin_config
		plugin_config = {}
		plugin_config["refresh_token"] = refresh_token
		plugin_config["encoded_client"] = encoded_client
		# Save plugin_config
		config_loader.save_plugin_config(PLUGIN_NAME, plugin_config)
	# POST /api/token refresh_token result
	elif json_result.has("access_token"):
		access_token = json_result["access_token"]


func set_state(data):
	# Skip one update if wait_to_update is set
	if wait_to_update:
		wait_to_update = false
		return

	# Don't need to update state if data hasn't changed
	if cur_data == data:
		return

	# Since we have new data, store it for the diff check
	cur_data = data

	# Set state
	# Volume
	volume_state = data["device"]["volume_percent"]

	# Shuffle
	shuffle_state = data["shuffle_state"]
	$Background/Controls/ShuffleButton.pressed = shuffle_state

	# Repeat
	repeat_state = repeat_modes.find(data["repeat_state"])
	$Background/Controls/RepeatButton.texture_normal = repeat_textures[repeat_state]

	# Play/Pause
	play_state = data["is_playing"]
	$Background/Controls/PlayPauseButton.pressed = play_state

	# I don't know why but sometimes item(song) is null, exit early if it is
	if not data["item"]:
		return

	set_song_state(data["item"])


# Expects a standard spotify song item
func set_song_state(data):
	# Sanity checks
	if not data or not data["name"] or not data["album"]:
		return

	# Track name
	track_name = data["name"]
	$Background/TrackName.text = track_name

	# Artist name
	artist = data["artists"][0]["name"]
	$Background/ArtistsName.text = artist

	# Cover art
	var tmp = data["album"]["images"][1]["url"]
	if art_url != tmp:
		art_url = tmp
		download_cover()

	# Album name
	album = data["album"]["name"]
	$Background/AlbumName.text = album


# Sends a http get request
# This is basically an abstraction for the standard godot http request
# only that it checks if the http client is free
func send_get_command(url, headers, method=0, body=""):
	if http_get.get_http_client_status() != 0:
		if OS.has_feature("editor"):
			push_warning("You're sending signals faster than we can handle")
		return
	http_get.request(url, headers, true, method, body)


# Sends a http post/put request (isn't enforced to be only post/put)
# endpoint:  the api endpoint, base_api_url gets added before it
# method:    the method to send for the http request
# no_update: if the next metadata_refresh is meant to be skipped
func send_command(endpoint, method, no_update=true, body=""):
	# TODO maybe create a queue
	if http_post.get_http_client_status() != 0:
		if OS.has_feature("editor"):
			push_warning("You're sending signals faster than we can handle")
		return
	wait_to_update = no_update
	var headers
	if not body:
		headers = ["Content-Length: 0", "Authorization: Bearer " + access_token]
	else:
		headers = ["Authorization: Bearer " + access_token]
	http_post.request(base_api_url + endpoint, headers, true, method, body)


# TODO maybe switch to godot download function
func download_cover():
	var filename = art_url.right(art_url.find_last("/") + 1) + ".jpeg"
	var args: PoolStringArray = ["-O", cache_dir_path + "/" + filename]
# warning-ignore:return_value_discarded
	args.insert(0, art_url)
	if OS.execute("wget", args):
		push_warning("Failed to download cover")
		return
	change_cover(filename)


# Create the texture from the downloaded cover art png
func create_texture_from_image(image_path):
	var image = Image.new()
	image.load(image_path)
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	return texture


func change_cover(filename):
	var complete_cover_path = config_loader.get_conf_dir() + "cache/" + filename
	$Background/AlbumArt.texture = create_texture_from_image(complete_cover_path)


func ensure_dir_exists(path):
	var dir = Directory.new()
	if dir.open(path) != OK:
		if dir.make_dir(path) != OK:
			push_warning("Couldn't create " + path + " dir")


# Deletes all files in cache_dir_path
# since we don't want to slowly fill the users .local dir
func clear_cache():
	var dir = Directory.new()
	if dir.open(cache_dir_path) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
	else:
		push_warning("An error occurred when trying to access the path.")


# Button functions
func _on_PlayPauseButton_pressed():
	if not playback_active:
		set_device(device_list[$Background/Controls/DeviceOptions.selected])
		playback_active = true
		return
	if play_state:
		send_command("/me/player/pause", 3)
		play_state = false
	else:
		send_command("/me/player/play", 3)
		play_state = true


func _on_SkipBackButton_pressed():
	send_command("/me/player/previous", 2, false)


func _on_DeviceOptions_item_selected(index:int):
	set_device(device_list[index])


func _on_SkipForwardButton_pressed():
	send_command("/me/player/next", 2, false)


func _on_RepeatButton_pressed():
	repeat_state += 1
	if repeat_state >= len(repeat_modes):
		repeat_state = 0
	$Background/Controls/RepeatButton.texture_normal = repeat_textures[repeat_state]
	send_command("/me/player/repeat?state=" + repeat_modes[repeat_state], 3)


func _on_ShuffleButton_pressed():
	shuffle_state = !shuffle_state
	send_command("/me/player/shuffle?state=" + str(shuffle_state).to_lower(), 3)


func _on_VolumeDownButton_pressed():
	if volume_state == 0:
		return
	if volume_state < 5:
		volume_state = 0
	else:
		volume_state -= 5
	send_command("/me/player/volume?volume_percent=" + str(volume_state), 3)


func _on_VolumeUpButton_pressed():
	if volume_state == 100:
		return
	if volume_state > 95:
		volume_state = 100
	else:
		volume_state += 5
	send_command("/me/player/volume?volume_percent=" + str(volume_state), 3)
