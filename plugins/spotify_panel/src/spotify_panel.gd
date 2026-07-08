extends PluginSceneBase
## A panel that displays and controls the current Spotify playback.

const PLUGIN_NAME = "Spotify Panel"
const BASE_API_URL: String = "https://api.spotify.com/v1"
const TOKEN_URL: String = "https://accounts.spotify.com/api/token"
# Repeat states in the order they are cycled through
const REPEAT_MODES: Array[String] = ["off", "context", "track"]
# How much one press of the volume buttons changes the volume
const VOLUME_STEP: int = 5
# How far the local progress clock is allowed to drift from a state poll's progress_ms
# before snapping to it, see _set_progress_state()
const PROGRESS_SYNC_TOLERANCE_MS: int = 1500
# How often the progress slider/labels tick forward locally between state polls
const PROGRESS_TICK_INTERVAL: float = 1.0
# Below this point into the song, skip back goes to the previous track; at/above it, skip
# back restarts the current track instead, matching the official Spotify clients
const SKIP_BACK_RESTART_THRESHOLD_MS: int = 10000
# How long a poll reporting the track just moved away from is treated as server-side lag rather
# than a genuinely unchanged track, see _consume_pending_track_change()
const TRACK_CHANGE_CONFIRM_WINDOW_MS: int = 4000
# How soon to retry the state poll while a track change isn't confirmed yet
const TRACK_CHANGE_RETRY_INTERVAL: float = 0.4

# Aspect ratio (x / y) above which the layout switches to side mode,
# see _update_responsive_layout()
const LANDSCAPE_ASPECT: float = 1.1
# The separation between elements inside the media/controls boxes
const ELEMENT_SEPARATION: float = 4.0
# The separation between the media and controls boxes (MainBox)
const BOX_SEPARATION: float = 8.0
# Minimum height that should stay reserved for the cover before the less important
# elements (song info labels, device selector) are shown in the same column
const COVER_RESERVED_HEIGHT: float = 100.0
# The margin kept around each playback control button, see _apply_button_margin()
const BUTTON_MARGIN: int = 16
# The largest extra gap that can grow between VolumeRow and DeviceMargin on a spacious panel,
# see _apply_volume_device_gap()
const MAX_VOLUME_DEVICE_GAP: float = 20.0
# Font size of the artist/album lines relative to the configured track name font size,
# matching the 20/15/13 defaults from the scene
const ARTIST_FONT_RATIO: float = 0.75
const ALBUM_FONT_RATIO: float = 0.65
# Vertical slack the song info clip containers keep beyond their label's font height
const SONG_INFO_CLIP_PADDING: float = 4.0
# The default panel background color, matches the StyleBoxFlat set on the scene root
const DEFAULT_BG_COLOR: Color = Color(1, 1, 1, 0.0470588)

const REPEAT_TEXTURES: Array[Texture2D] = [
	preload("res://plugins/spotify_panel/resources/repeat.tres"),
	preload("res://plugins/spotify_panel/resources/repeat_selected.tres"),
	preload("res://plugins/spotify_panel/resources/repeat_1_selected.tres"),
]

# Spotify api credentials
var refresh_token: String = ""  # The token with which a new access_token can be generated
var access_token: String = ""  # The token with which the requests get made, expires after 1 hour
var encoded_client: String = ""  # Base64 encoded client_id and client_secret
var authenticated: bool = false  # Stop all api traffic while not authenticated

# Playback state
var play_state: bool = false
var shuffle_state: bool = false
var repeat_state: int = 0  # Index into REPEAT_MODES
var volume_state: int = 0
var playback_active: bool = true  # Gets set to false when the api doesn't provide playback-state
var device_list: Array = []
var art_url: String = ""

var _refresh_interval: float = 5.0
var _max_button_size: int = 64
var _hide_controls: bool = false
var _controls_on_left: bool = false
var _bg_color: Color = DEFAULT_BG_COLOR
var _bg_style: StyleBoxFlat
# True while the user is dragging the volume slider, blocks state updates from moving it
var _volume_dragging: bool = false
# Skips one state update, useful for e.g. the play/pause button as the next state
# poll may not reflect the change yet and would revert the button.
var _skip_next_state_update: bool = false
# True while the poll timers run, i.e. the panel is visible. Responses that were still in
# flight at _stop_polling() are processed normally, but must not issue new requests or rearm
# _end_timer, as that would keep a poll-per-track cycle alive in the background.
var _polling: bool = false
var _cur_data: Variant = null  # Last state response, used to check if changes happened
var _cur_device_data: Variant = null  # Last devices response, used to check if changes happened

# Track progress state. Progress is tracked locally between polls via _progress_anchor_ms/
# _progress_anchor_ticks (the progress and Time.get_ticks_msec() at the last known-good point)
# rather than being incremented every tick, so it can't drift from repeated small timer errors.
var _duration_ms: int = 0
var _progress_anchor_ms: int = 0
var _progress_anchor_ticks: int = 0
# True while the user is dragging the progress slider, blocks state updates from moving it
var _progress_dragging: bool = false
# Id (or name, as a fallback) of the currently playing track, used to detect track changes
var _current_track_id: String = ""
# Track id being moved away from by a skip or the current track ending, see
# _consume_pending_track_change()
var _pending_track_change_from_id: String = ""
var _pending_track_change_since_ticks: int = 0
# Prefetched data for the track expected to play next, see _request_playback_queue()
var _next_track_data: Dictionary = {}
# Cover art urls that have been fully downloaded to cache_dir_path, see _ensure_cover_cached()
var _cached_cover_urls: Dictionary = {}

# Api requests are sent one at a time in order, see _process_queue()
var _request_queue: Array[SpotifyApiRequest] = []
var _active_request: SpotifyApiRequest = null
var _http_request: HTTPRequest
var _metadata_timer: Timer
var _devices_timer: Timer
var _progress_timer: Timer  # Ticks the progress slider/labels forward locally, see PROGRESS_TICK_INTERVAL
var _end_timer: Timer  # One-shot, fires when the current track is expected to end, see _schedule_song_end()
# One-shot, retries the state poll while a track change isn't confirmed yet
var _track_change_retry_timer: Timer

var _credentials_config: Config = Config.new()

# The outer margins around the whole panel content (both sides summed), derived from the
# configured margin in _apply_outer_margin()
var _outer_margins: float = 0.0

# Download cache for covers
@onready var cache_dir_path: String = PluginCoordinator.get_cache_dir(PLUGIN_NAME)


func _init() -> void:
	config.add_float(
		"Refresh Interval",
		"refresh_interval",
		5.0,
		"How often the playback state is fetched from Spotify, in seconds"
	)
	config.add_int(
		"Max button size",
		"max_button_size",
		64,
		"Caps how large the playback control buttons can grow on large panels"
	)
	config.add_int(
		"Margin", "margin", 16, "The margin between the panel content and the panel edges"
	)
	config.add_int(
		"Font size",
		"font_size",
		20,
		"Font size of the track name; the artist and album lines scale along with it"
	)
	config.add_bool(
		"Hide controls", "hide_controls", false, "Only show the cover and the song info"
	)
	config.add_bool(
		"Controls on the left",
		"controls_on_left",
		false,
		"When the controls are shown next to the cover, show them on the left instead of the right"
	)
	config.add_color("Background color", "background_color", DEFAULT_BG_COLOR)


func _ready() -> void:
	super()

	_bg_style = get_theme_stylebox("panel").duplicate()
	add_theme_stylebox_override("panel", _bg_style)
	_apply_background_color()

	ConfLib.ensure_dir_exists(cache_dir_path)

	_credentials_config.set_config_path(conf_dir.path_join("credentials.json"))
	_credentials_config.add_string("Refresh token", "refresh_token", "")
	_credentials_config.add_string("Encoded client", "encoded_client", "")
	_load_credentials()
	_update_setup_hint()

	# Clear cache dir to not fill the user dir with endless album arts
	_clear_cache()

	_http_request = HTTPRequest.new()
	_http_request.request_completed.connect(_on_request_completed)
	add_child(_http_request)

	_metadata_timer = Timer.new()
	_metadata_timer.timeout.connect(_request_state)
	add_child(_metadata_timer)
	_devices_timer = Timer.new()
	_devices_timer.timeout.connect(_request_devices)
	add_child(_devices_timer)
	_apply_refresh_interval()

	_progress_timer = Timer.new()
	_progress_timer.wait_time = PROGRESS_TICK_INTERVAL
	_progress_timer.timeout.connect(_update_progress_display)
	add_child(_progress_timer)
	_end_timer = Timer.new()
	_end_timer.one_shot = true
	_end_timer.timeout.connect(_on_song_end_timer_timeout)
	add_child(_end_timer)
	_track_change_retry_timer = Timer.new()
	_track_change_retry_timer.one_shot = true
	_track_change_retry_timer.timeout.connect(_on_track_change_retry_timer_timeout)
	add_child(_track_change_retry_timer)

	_connect_controls()
	resized.connect(_update_responsive_layout)
	resized.connect(_apply_button_margin)
	_update_responsive_layout()
	_apply_button_margin()

	# The panel may be created in a background tab; scene_show() starts polling once it's shown
	if is_visible_in_tree():
		_start_polling()


## Loads the settings from [member PluginSceneBase.config].
func handle_config() -> void:
	var data: Dictionary = config.get_as_dict()

	_refresh_interval = maxf(data["refresh_interval"], 0.5)
	_apply_refresh_interval()

	_max_button_size = maxi(int(data["max_button_size"]), 1)
	_hide_controls = data["hide_controls"]
	_controls_on_left = data["controls_on_left"]
	_apply_outer_margin(maxi(int(data["margin"]), 0))
	_apply_font_size(maxi(int(data["font_size"]), 1))
	# Must run after _hide_controls, the outer margin and the font size are set, since the
	# layout depends on them.
	_update_responsive_layout()
	_apply_button_margin()

	_bg_color = Color.hex(data["background_color"])
	_apply_background_color()


## Called when panel config is supposed to be edited.
func edit_config() -> void:
	var config_editor: Config.ConfigEditor = config.generate_editor()
	config_editor.name = "Settings"

	var auth_wizard: AuthWizard = AuthWizard.new(authenticated)
	auth_wizard.name = "Authentication Wizard"
	auth_wizard.auth_completed.connect(_on_auth_wizard_auth_completed)

	PopupManager.init_popup(
		[config_editor, auth_wizard],
		func apply_and_save() -> void:
			config_editor.apply()
			config_editor.save()
	)


func scene_show() -> void:
	super()
	_start_polling()


func scene_hide() -> void:
	super()
	_stop_polling()


func _apply_refresh_interval() -> void:
	if not _metadata_timer:
		return
	_metadata_timer.wait_time = _refresh_interval
	# Devices don't need to be refreshed as often
	_devices_timer.wait_time = _refresh_interval * 3


func _apply_background_color() -> void:
	if not _bg_style:
		return
	_bg_style.bg_color = _bg_color


# Applies [param margin] to all four sides of the %Margin node and updates the total
# the layout budgets are computed with.
func _apply_outer_margin(margin: int) -> void:
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		%Margin.add_theme_constant_override(side, margin)
	_outer_margins = margin * 2.0


# Applies the configured font size to the song info labels, scaling the artist/album lines
# proportionally. The clip containers get resized to the resulting font heights, since their
# fixed heights from the scene only fit the default sizes.
func _apply_font_size(font_size: int) -> void:
	var sizes: Dictionary = {
		%TrackName: font_size,
		%ArtistsName: maxi(roundi(font_size * ARTIST_FONT_RATIO), 1),
		%AlbumName: maxi(roundi(font_size * ALBUM_FONT_RATIO), 1),
	}
	for label: Label in sizes:
		label.add_theme_font_size_override("font_size", sizes[label])
		var font_height: float = label.get_theme_font("font").get_height(sizes[label])
		label.get_parent().custom_minimum_size.y = ceilf(font_height + SONG_INFO_CLIP_PADDING)


# Applies BUTTON_MARGIN around the control buttons, capping them at _max_button_size while
# staying square (see _target_button_size()).
#
# Derived directly from panel_size rather than by reading wrapper.size back: horizontally, a
# MarginContainer's own minimum size includes its current margin, so a live measurement is
# self-referential and can lag behind a fast resize; vertically, the row's height would be
# contested with %AlbumArt's sizing in _update_responsive_layout(). panel_size sidesteps both.
func _apply_button_margin() -> void:
	var panel_size: Vector2 = size
	var landscape: bool = _is_landscape(panel_size)
	var row_width: float = _content_column_width(panel_size, landscape)

	for row in [%PlaybackControls, %ExtraControls]:
		var per_button_width: float = row_width / row.get_child_count()
		for wrapper in row.get_children():
			var button: Control = wrapper.get_child(0)
			var target: float = _target_button_size(button.custom_minimum_size.x, per_button_width)
			var margin_x: int = maxi(BUTTON_MARGIN, ceili((per_button_width - target) / 2.0))
			# margin_x is an int and may round target down by a pixel; deriving the height from
			# the post-rounding width, not target, keeps the button exactly square.
			var rendered_size: float = per_button_width - margin_x * 2.0
			# PlaybackControls/ExtraControls don't expand vertically (see the .tscn), so this is
			# exactly what ControlsBox gives them - must match _button_row_min_height()'s reservation.
			wrapper.custom_minimum_size.y = rendered_size + BUTTON_MARGIN * 2.0
			wrapper.add_theme_constant_override("margin_left", margin_x)
			wrapper.add_theme_constant_override("margin_right", margin_x)
			wrapper.add_theme_constant_override("margin_top", BUTTON_MARGIN)
			wrapper.add_theme_constant_override("margin_bottom", BUTTON_MARGIN)


func _load_credentials() -> void:
	_credentials_config.load_config()
	var credentials: Dictionary = _credentials_config.get_as_dict()
	if credentials["refresh_token"] != "":
		refresh_token = credentials["refresh_token"]
		encoded_client = credentials["encoded_client"]
		authenticated = true


# Shows a setup hint instead of the panel content until an account is connected.
func _update_setup_hint() -> void:
	%SetupHint.visible = not authenticated
	%MainBox.visible = authenticated


func _save_credentials() -> void:
	_credentials_config.apply_dict(
		{"refresh_token": refresh_token, "encoded_client": encoded_client}
	)
	_credentials_config.save()


func _connect_controls() -> void:
	%PlayPauseButton.pressed.connect(_on_play_pause_button_pressed)
	%SkipBackButton.pressed.connect(_on_skip_back_button_pressed)
	%SkipForwardButton.pressed.connect(_on_skip_forward_button_pressed)
	%ShuffleButton.pressed.connect(_on_shuffle_button_pressed)
	%RepeatButton.pressed.connect(_on_repeat_button_pressed)
	%VolumeDownButton.pressed.connect(_on_volume_down_button_pressed)
	%VolumeUpButton.pressed.connect(_on_volume_up_button_pressed)
	%VolumeSlider.drag_started.connect(_on_volume_slider_drag_started)
	%VolumeSlider.drag_ended.connect(_on_volume_slider_drag_ended)
	%ProgressSlider.drag_started.connect(_on_progress_slider_drag_started)
	%ProgressSlider.drag_ended.connect(_on_progress_slider_drag_ended)
	%DeviceOptions.item_selected.connect(_on_device_options_item_selected)


# Whether panel_size is wide enough to switch to the side-by-side layout, see
# _update_responsive_layout().
func _is_landscape(panel_size: Vector2) -> bool:
	return panel_size.x > panel_size.y * LANDSCAPE_ASPECT


# Width of a single column of panel content: the full available width, or half of it in
# landscape mode where the cover and controls sit side by side.
func _content_column_width(panel_size: Vector2, landscape: bool) -> float:
	var column_width: float = panel_size.x - _outer_margins
	if landscape and not _hide_controls:
		column_width = (column_width - BOX_SEPARATION) / 2.0
	return column_width


# Capped at per_button_width rather than just _max_button_size, since the buttons are square and
# shouldn't grow taller than what's actually achievable width-wise.
func _target_button_size(button_min: float, per_button_width: float) -> float:
	return maxf(button_min, minf(_max_button_size, per_button_width))


# Rearranges and hides ui elements based on the current panel size and settings.
func _update_responsive_layout() -> void:
	var panel_size: Vector2 = size
	var landscape: bool = _is_landscape(panel_size)

	# Cover + song info next to the controls in landscape, above them in portrait
	%MainBox.vertical = not landscape
	%ControlsBox.visible = not _hide_controls
	# In landscape the controls can be configured to sit on the left instead
	%MainBox.move_child(%MediaBox, 1 if landscape and _controls_on_left else 0)

	# The progress bar sits with the rest of the controls in landscape, but is grouped with the
	# song info in portrait instead, between the cover art and the track name.
	%ProgressRow.visible = not _hide_controls
	if landscape:
		if %ProgressRow.get_parent() != %ControlsBox:
			%ProgressRow.reparent(%ControlsBox, false)
		%ControlsBox.move_child(%ProgressRow, 0)
	else:
		if %ProgressRow.get_parent() != %MediaBox:
			%ProgressRow.reparent(%MediaBox, false)
		%MediaBox.move_child(%ProgressRow, 1)

	# The cover is never hidden, it simply takes the height left over in its column, capped
	# at a square. The other elements get hidden when they no longer fit into the panel.
	# Elements sharing a column with the cover additionally reserve COVER_RESERVED_HEIGHT
	# for it, so they don't squeeze the cover out just because they would still fit themselves.
	var media_budget: float = panel_size.y - _outer_margins - _element_min_height(%TrackNameClip)
	var cover_budget: float
	if _hide_controls:
		cover_budget = _fit_elements(
			[%ArtistNameClip, %AlbumNameClip], media_budget, [%ArtistNameClip, %AlbumNameClip]
		)
	elif landscape:
		# Song info and controls sit in separate columns, so each has its own budget
		var controls_budget: float = panel_size.y - _outer_margins - _core_controls_min_height()
		var controls_leftover: float = _fit_elements(
			[%VolumeRow, %ExtraControls, %DeviceMargin], controls_budget
		)
		_apply_volume_device_gap(controls_leftover)
		cover_budget = _fit_elements(
			[%ArtistNameClip, %AlbumNameClip], media_budget, [%ArtistNameClip, %AlbumNameClip]
		)
	else:
		# Everything shares one column in portrait
		var budget: float = media_budget - BOX_SEPARATION - _core_controls_min_height()
		cover_budget = _fit_elements(
			[%VolumeRow, %ExtraControls, %ArtistNameClip, %AlbumNameClip, %DeviceMargin],
			budget,
			[%ArtistNameClip, %AlbumNameClip, %DeviceMargin]
		)

	# Cap the cover at a square so a very tall panel doesn't stretch it indefinitely.
	# The surplus space then goes to the controls instead or the content gets centered.
	var cover_width: float = _content_column_width(panel_size, landscape)
	%AlbumArt.custom_minimum_size.y = clampf(cover_budget, 0.0, cover_width)
	if not landscape and not _hide_controls:
		# ControlsBox is the sole vertical-expand child of MainBox in portrait, so whatever
		# cover_budget doesn't use (capped at cover_width) flows into it instead.
		_apply_volume_device_gap(maxf(0.0, cover_budget - cover_width))


# Grows the spacer between VolumeRow and DeviceMargin to use up to MAX_VOLUME_DEVICE_GAP of
# [param leftover], giving them a bit more separation as touch targets on a spacious panel.
func _apply_volume_device_gap(leftover: float) -> void:
	var gap: float = 0.0
	if %VolumeRow.visible and %DeviceMargin.visible:
		gap = clampf(leftover, 0.0, MAX_VOLUME_DEVICE_GAP)
	%VolumeDeviceSpacer.custom_minimum_size.y = gap


# Shows [param elements] in order as long as [param budget] allows, hides the rest.
# Once an element got hidden, all elements after it get hidden as well, so a lower
# priority element can never show in place of a higher priority one.
# Elements in [param reserved_elements] only get shown if COVER_RESERVED_HEIGHT
# would still be left over afterwards.
# Returns the budget that remains after the shown elements.
func _fit_elements(
	elements: Array[Control], budget: float, reserved_elements: Array[Control] = []
) -> float:
	var fits: bool = true
	for element in elements:
		if fits:
			var reserved: float = COVER_RESERVED_HEIGHT if element in reserved_elements else 0.0
			if budget - _element_min_height(element) - reserved >= 0.0:
				budget -= _element_min_height(element)
			else:
				fits = false
		element.visible = fits
	return budget


# Height always reserved for the progress bar and playback buttons, which unlike the other
# controls are never hidden by _fit_elements(). Reserved regardless of which container
# %ProgressRow currently lives in, see the reparenting in _update_responsive_layout().
func _core_controls_min_height() -> float:
	return _element_min_height(%ProgressRow) + _element_min_height(%PlaybackControls)


# The minimum height [param element] occupies in its container.
func _element_min_height(element: Control) -> float:
	if element == %PlaybackControls or element == %ExtraControls:
		return _button_row_min_height(element) + ELEMENT_SEPARATION
	return element.get_combined_minimum_size().y + ELEMENT_SEPARATION


# Height a button row (%PlaybackControls/%ExtraControls) will occupy. Must match what
# _apply_button_margin() actually sets, or _fit_elements() reserves the wrong amount of space
# for it and other elements end up hidden or pushed out.
func _button_row_min_height(row: Control) -> float:
	var panel_size: Vector2 = size
	var landscape: bool = _is_landscape(panel_size)
	var per_button_width: float = (
		_content_column_width(panel_size, landscape) / row.get_child_count()
	)
	var min_height: float = 0.0
	for wrapper in row.get_children():
		var button: Control = wrapper.get_child(0)
		var target: float = _target_button_size(button.custom_minimum_size.x, per_button_width)
		min_height = maxf(min_height, target + BUTTON_MARGIN * 2.0)
	return min_height


# Starts the poll timers and immediately polls once for a fast startup.
func _start_polling() -> void:
	if not authenticated or not _metadata_timer:
		return
	_polling = true
	_metadata_timer.start()
	_devices_timer.start()
	_progress_timer.start()
	_request_state()
	_request_devices()
	_request_playback_queue()


func _stop_polling() -> void:
	if not _metadata_timer:
		return
	_polling = false
	_metadata_timer.stop()
	_devices_timer.stop()
	_progress_timer.stop()
	_end_timer.stop()
	_track_change_retry_timer.stop()


# Queues a playback state poll unless one is already pending.
func _request_state() -> void:
	if not _polling:
		return
	if _is_request_pending(BASE_API_URL + "/me/player"):
		return
	var request: SpotifyApiRequest = SpotifyApiRequest.new()
	request.url = BASE_API_URL + "/me/player"
	request.callback = _on_state_response
	_enqueue_request(request)


# Queues a devices poll unless one is already pending.
func _request_devices() -> void:
	if not _polling:
		return
	if _is_request_pending(BASE_API_URL + "/me/player/devices"):
		return
	var request: SpotifyApiRequest = SpotifyApiRequest.new()
	request.url = BASE_API_URL + "/me/player/devices"
	request.callback = _on_devices_response
	_enqueue_request(request)


# Queues a poll of the upcoming track, used to prefetch its info/cover so playback can move
# to it without a visible delay once the current track ends, see _on_song_end_timer_timeout().
func _request_playback_queue() -> void:
	if not _polling:
		return
	if _is_request_pending(BASE_API_URL + "/me/player/queue"):
		return
	var request: SpotifyApiRequest = SpotifyApiRequest.new()
	request.url = BASE_API_URL + "/me/player/queue"
	request.callback = _on_queue_response
	_enqueue_request(request)


# Queues a command for the Spotify api.
# skip_state_update: discards the next state poll, used when it may not yet reflect an
#                    optimistically applied change
func _send_command(
	endpoint: String, method: HTTPClient.Method, body: String = "", skip_state_update: bool = true
) -> void:
	var request: SpotifyApiRequest = SpotifyApiRequest.new()
	request.url = BASE_API_URL + endpoint
	request.method = method
	request.body = body
	_skip_next_state_update = _skip_next_state_update or skip_state_update
	_enqueue_request(request)


# Queues a skip command (previous/next). Skips get their own path instead of _send_command()
# since a successful skip resets the local playback state, and the endpoints can return a
# non-JSON body on success that shouldn't be parsed.
func _send_skip_command(endpoint: String) -> void:
	var request: SpotifyApiRequest = SpotifyApiRequest.new()
	request.url = BASE_API_URL + endpoint
	request.method = HTTPClient.METHOD_POST
	request.callback = _on_skip_command_completed
	request.parse_json = false
	_enqueue_request(request)


func _create_token_request() -> SpotifyApiRequest:
	var request: SpotifyApiRequest = SpotifyApiRequest.new()
	request.url = TOKEN_URL
	request.method = HTTPClient.METHOD_POST
	request.use_bearer = false
	request.headers.append("Content-Type: application/x-www-form-urlencoded")
	request.headers.append("Authorization: Basic " + encoded_client)
	request.body = "grant_type=refresh_token&refresh_token=" + refresh_token
	request.callback = _on_token_response
	return request


func _is_request_pending(url: String) -> bool:
	if _active_request and _active_request.url == url:
		return true
	for request in _request_queue:
		if request.url == url:
			return true
	return false


func _enqueue_request(request: SpotifyApiRequest) -> void:
	_request_queue.append(request)
	_process_queue()


# Sends the next queued request if none is currently active.
# If the front request requires a not (yet) available access token,
# a token request gets queued in before it.
func _process_queue() -> void:
	if _active_request or _request_queue.is_empty():
		return
	if not authenticated:
		_request_queue.clear()
		return

	if _request_queue.front().use_bearer and access_token.is_empty():
		_request_queue.push_front(_create_token_request())

	var request: SpotifyApiRequest = _request_queue.pop_front()
	_active_request = request

	var headers: PackedStringArray = request.headers.duplicate()
	if request.use_bearer:
		headers.append("Authorization: Bearer " + access_token)
	if request.body.is_empty() and request.method != HTTPClient.METHOD_GET:
		headers.append("Content-Length: 0")

	var error: Error = _http_request.request(request.url, headers, request.method, request.body)
	if error != OK:
		push_error("Failed to send request to %s: %s" % [request.url, error_string(error)])
		_active_request = null


func _on_request_completed(
	result: int, response_code: int, _response_headers: PackedStringArray, body: PackedByteArray
) -> void:
	var request: SpotifyApiRequest = _active_request
	_active_request = null

	if result != HTTPRequest.RESULT_SUCCESS:
		# Drop all pending requests so e.g. a missing connection can't loop token refreshes,
		# polling will try again on its own.
		_request_queue.clear()
		if OS.has_feature("editor"):
			push_warning("Spotify request to %s failed with result %d" % [request.url, result])
		return

	# Refresh the expired access token and retry the request once
	if (
		response_code == HTTPClient.RESPONSE_UNAUTHORIZED
		and request.use_bearer
		and not request.retried
	):
		access_token = ""
		request.retried = true
		_request_queue.push_front(request)
		_process_queue()
		return

	if request.callback.is_valid():
		var data: Variant = null
		if not body.is_empty() and request.parse_json:
			data = JSON.parse_string(body.get_string_from_utf8())
			if data == null and OS.has_feature("editor"):
				push_warning(
					"Failed to parse JSON response from %s (%d bytes)" % [request.url, body.size()]
				)
		request.callback.call(response_code, data)

	_process_queue()


func _on_token_response(response_code: int, data: Variant) -> void:
	if (
		response_code != HTTPClient.RESPONSE_OK
		or typeof(data) != TYPE_DICTIONARY
		or not data.has("access_token")
	):
		# Drop everything that was waiting for the new token, polling will try again on its own
		_request_queue.clear()
		push_warning("Failed to refresh Spotify access token (response code %d)" % response_code)
		return

	access_token = data["access_token"]
	# Spotify can rotate the refresh token
	if data.has("refresh_token") and data["refresh_token"] != refresh_token:
		refresh_token = data["refresh_token"]
		_save_credentials()


func _on_state_response(response_code: int, data: Variant) -> void:
	# This code happens when playback is not active
	if response_code == HTTPClient.RESPONSE_NO_CONTENT:
		playback_active = false
		return
	if response_code != HTTPClient.RESPONSE_OK or typeof(data) != TYPE_DICTIONARY:
		if OS.has_feature("editor"):
			push_warning("Unexpected state response code: %d" % response_code)
		return

	playback_active = true
	_set_state(data)


func _on_devices_response(response_code: int, data: Variant) -> void:
	if response_code != HTTPClient.RESPONSE_OK or typeof(data) != TYPE_DICTIONARY:
		if OS.has_feature("editor"):
			push_warning("Unexpected devices response code: %d" % response_code)
		return

	_generate_device_list(data["devices"])


func _on_queue_response(response_code: int, data: Variant) -> void:
	if response_code != HTTPClient.RESPONSE_OK or typeof(data) != TYPE_DICTIONARY:
		return

	var queue: Array = data.get("queue", [])
	_next_track_data = queue[0] if not queue.is_empty() else {}
	_prefetch_next_cover()


func _set_state(data: Dictionary) -> void:
	# Skip one update if a command was sent since the last poll
	if _skip_next_state_update:
		_skip_next_state_update = false
		return

	# Don't need to update state if data hasn't changed
	if _cur_data == data:
		return
	_cur_data = data

	# Some players don't support remote volume control, disable the slider for those
	var supports_volume: bool = data["device"].get("supports_volume", true)
	%VolumeSlider.editable = supports_volume
	if not supports_volume:
		# A slider that turned non-editable mid-drag never emits drag_ended, so reset manually
		_volume_dragging = false

	# Volume can be null for devices that don't allow remote volume control
	var volume: Variant = data["device"].get("volume_percent")
	if volume != null:
		volume_state = int(volume)
		if not _volume_dragging:
			%VolumeSlider.set_value_no_signal(volume_state)

	# A changed shuffle/repeat mode also changes what plays next, e.g. when toggled remotely
	# from another device. Locally pressed buttons apply their state optimistically, so they
	# never differ here and re-request the queue themselves instead.
	var new_shuffle_state: bool = data["shuffle_state"]
	var new_repeat_state: int = maxi(REPEAT_MODES.find(data["repeat_state"]), 0)
	if new_shuffle_state != shuffle_state or new_repeat_state != repeat_state:
		_request_playback_queue()

	shuffle_state = new_shuffle_state
	%ShuffleButton.button_pressed = shuffle_state

	repeat_state = new_repeat_state
	%RepeatButton.texture_normal = REPEAT_TEXTURES[repeat_state]

	play_state = data["is_playing"]
	%PlayPauseButton.button_pressed = play_state

	# item (the song) can be null, e.g. in a private session
	if data.get("item"):
		# A local track change can outrun Spotify's server-side state; skip a poll that still
		# reports the old track instead of flickering the display back to it, see
		# _consume_pending_track_change().
		if _consume_pending_track_change(data["item"]):
			_track_change_retry_timer.start(TRACK_CHANGE_RETRY_INTERVAL)
			return
		_set_song_state(data["item"])
		_set_progress_state(data)


# Whether [param item] still reports the track being moved away from by _reset_state_for_skip()
# or _apply_prefetched_next_track(), see _set_state(). Once the change is confirmed (or the
# confirm window expired), clears the pending change and refreshes the queue, since a queue
# fetched while the server still lagged behind the change may be stale.
func _consume_pending_track_change(item: Dictionary) -> bool:
	if _pending_track_change_from_id.is_empty():
		return false
	var within_window: bool = (
		Time.get_ticks_msec() - _pending_track_change_since_ticks < TRACK_CHANGE_CONFIRM_WINDOW_MS
	)
	if _track_id_of(item) == _pending_track_change_from_id and within_window:
		return true
	_pending_track_change_from_id = ""
	_request_playback_queue()
	return false


# Id (or name, as a fallback) of a standard spotify song item, used to detect track changes.
func _track_id_of(item: Dictionary) -> String:
	return str(item.get("id", item.get("name", "")))


# Expects a standard spotify song item.
func _set_song_state(data: Dictionary) -> void:
	if not data.get("name") or not data.get("album"):
		return

	# The queue (and therefore what's playing next) can change whenever the track itself does
	var track_id: String = _track_id_of(data)
	if track_id != _current_track_id:
		_current_track_id = track_id
		_request_playback_queue()

	%TrackName.set_new_text(data["name"])
	if not data["artists"].is_empty():
		%ArtistsName.set_new_text(data["artists"][0]["name"])
	%AlbumName.set_new_text(data["album"]["name"])

	var new_art_url: String = _cover_url_of(data)
	if not new_art_url.is_empty() and new_art_url != art_url:
		art_url = new_art_url
		_download_cover()


# The cover url of a standard spotify song item: 300x300 (the middle size), which makes
# most sense.
# TODO make this configurable
func _cover_url_of(item: Dictionary) -> String:
	var images: Array = item.get("album", {}).get("images", [])
	if images.is_empty():
		return ""
	return images[mini(1, images.size() - 1)]["url"]


# Updates the tracked song duration/progress from a state poll. The local progress clock is
# only snapped to the polled value if it drifted from what was predicted by more than
# PROGRESS_SYNC_TOLERANCE_MS, so small network jitter doesn't cause the slider to jump.
func _set_progress_state(data: Dictionary) -> void:
	_set_duration(int(data["item"].get("duration_ms", 0)))
	var progress_ms: int = int(data.get("progress_ms", 0))

	if not _progress_dragging:
		var predicted: int = _get_predicted_progress_ms()
		var drift_ms: int = absi(predicted - progress_ms)
		if drift_ms > PROGRESS_SYNC_TOLERANCE_MS:
			_set_progress_anchor(progress_ms)
		_update_progress_display()

	_schedule_song_end()


# Applies [param duration_ms] as the current track duration to the slider range and label.
func _set_duration(duration_ms: int) -> void:
	if duration_ms == _duration_ms:
		return
	_duration_ms = duration_ms
	%ProgressSlider.max_value = maxi(duration_ms, 1)
	%DurationLabel.text = _format_time(duration_ms)


# The current playback position, predicted locally from the last known-good progress and how
# long it's been playing since, without needing a fresh poll.
func _get_predicted_progress_ms() -> int:
	var predicted: int = _progress_anchor_ms
	if play_state:
		predicted += Time.get_ticks_msec() - _progress_anchor_ticks
	return clampi(predicted, 0, _duration_ms)


# Sets [param progress_ms] as the current known-good playback position, resetting the point
# in time that _get_predicted_progress_ms() measures elapsed playback from.
func _set_progress_anchor(progress_ms: int) -> void:
	_progress_anchor_ms = clampi(progress_ms, 0, _duration_ms)
	_progress_anchor_ticks = Time.get_ticks_msec()


func _update_progress_display() -> void:
	if _progress_dragging:
		return
	var predicted: int = _get_predicted_progress_ms()
	%ProgressSlider.set_value_no_signal(predicted)
	%CurrentTimeLabel.text = _format_time(predicted)


func _format_time(ms: int) -> String:
	@warning_ignore("integer_division")
	var total_seconds: int = maxi(ms, 0) / 1000
	@warning_ignore("integer_division")
	return "%d:%02d" % [total_seconds / 60, total_seconds % 60]


# (Re)schedules _end_timer to fire when the current track is expected to end, so playback can
# move to the next track without waiting for the next regularly scheduled state poll.
func _schedule_song_end() -> void:
	# While hidden nothing may rearm the timer; the refresh on the next scene_show()
	# reschedules it.
	if not _polling or not play_state or _duration_ms <= 0:
		_end_timer.stop()
		return
	var remaining_ms: int = _duration_ms - _get_predicted_progress_ms()
	_end_timer.start(maxf(remaining_ms / 1000.0, 0.1))


# Called when the current track is expected to have ended. Optimistically swaps to the
# prefetched next track (unless the track is set to repeat) so the panel updates immediately,
# then polls to confirm/correct it.
func _on_song_end_timer_timeout() -> void:
	# Don't yank the slider out from under the user mid-drag, try again shortly instead.
	if _progress_dragging:
		_end_timer.start(0.5)
		return

	if REPEAT_MODES[repeat_state] == "track":
		_set_progress_anchor(0)
	elif _next_track_data.is_empty():
		# Nothing prefetched to swap to; leave the display at the end of the track and just
		# poll until the server reports what actually plays next.
		_track_change_retry_timer.start(TRACK_CHANGE_RETRY_INTERVAL)
		return
	else:
		_apply_prefetched_next_track()
	_update_progress_display()
	_schedule_song_end()
	_request_state()


func _apply_prefetched_next_track() -> void:
	# Same reasoning as _reset_state_for_skip(): arm the guard against a poll racing this swap.
	_pending_track_change_from_id = _current_track_id
	_pending_track_change_since_ticks = Time.get_ticks_msec()
	_set_song_state(_next_track_data)
	_set_duration(int(_next_track_data.get("duration_ms", _duration_ms)))
	_set_progress_anchor(0)
	_next_track_data = {}


# Seeks to [param position_ms], updating the local progress clock immediately and sending the
# change to the api.
func _seek_to(position_ms: int) -> void:
	position_ms = clampi(position_ms, 0, _duration_ms)
	_set_progress_anchor(position_ms)
	_update_progress_display()
	_schedule_song_end()
	_send_command("/me/player/seek?position_ms=%d" % position_ms, HTTPClient.METHOD_PUT)


# Fills the device dropdown from [param data], selecting the currently active device.
func _generate_device_list(data: Array) -> void:
	# Only regenerate if something changed
	if _cur_device_data == data:
		return
	_cur_device_data = data

	# Sort device_list as otherwise the order changes constantly
	device_list = data.duplicate()
	device_list.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a["name"] < b["name"]
	)

	%DeviceOptions.clear()
	if device_list.is_empty():
		_add_device_placeholder()
		return
	var active_index: int = 0
	for i in device_list.size():
		%DeviceOptions.add_item(device_list[i]["name"], i)
		if device_list[i]["is_active"]:
			active_index = i
	%DeviceOptions.select(active_index)


# Non-selectable stand-in item so the dropdown keeps its size while no real devices are known.
# The scene ships with the same item so the size is right before the first devices response.
func _add_device_placeholder() -> void:
	%DeviceOptions.add_item("Devices")
	%DeviceOptions.set_item_disabled(0, true)
	%DeviceOptions.select(0)


# Transfers playback to [param device].
func _set_output_device(device: Dictionary, play: bool = true) -> void:
	if playback_active:
		var body: String = JSON.stringify({"device_ids": [device["id"]], "play": play})
		_send_command("/me/player", HTTPClient.METHOD_PUT, body)
	elif play:
		# The endpoint above is currently broken when trying to transfer inactive playback to a
		# device. Instead the start/resume playback endpoint restarts the previous playback on
		# the requested device (the empty brackets body is for some reason important).
		_send_command("/me/player/play?device_id=%s" % device["id"], HTTPClient.METHOD_PUT, "{}")
		playback_active = true


# Downloads the cover from [member art_url] and applies it once finished. The download is
# skipped if the cover is already cached, e.g. prefetched by _prefetch_next_cover().
func _download_cover() -> void:
	var url: String = art_url
	var file_path: String = await _ensure_cover_cached(url)

	# A newer cover may have been requested while this one was downloading
	if url != art_url:
		return

	var image: Image = Image.load_from_file(file_path)
	if image:
		%AlbumArt.texture = ImageTexture.create_from_image(image)


# Downloads the cover for [member _next_track_data] ahead of time, so _download_cover() can
# swap to it instantly once the current track ends instead of waiting on a fresh download.
func _prefetch_next_cover() -> void:
	if _next_track_data.is_empty():
		return
	var url: String = _cover_url_of(_next_track_data)
	if not url.is_empty():
		_ensure_cover_cached(url)


# Downloads [param url] into the cover cache unless it's already fully cached, and returns
# the cached file path.
func _ensure_cover_cached(url: String) -> String:
	var file_path: String = cache_dir_path.path_join(url.get_file() + ".jpeg")
	if not _cached_cover_urls.get(url, false):
		var downloader: Downloader = Downloader.new()
		downloader.download(url, file_path)
		await downloader.download_completed
		_cached_cover_urls[url] = true
	return file_path


# Deletes all downloaded covers, since we don't want to slowly fill the user's cache dir.
func _clear_cache() -> void:
	for file in ConfLib.list_files_in_dir(cache_dir_path):
		DirAccess.remove_absolute(file)


# Sets the volume, updating the slider and sending the change to the api.
func _set_volume(new_volume: int) -> void:
	new_volume = clampi(new_volume, 0, 100)
	%VolumeSlider.set_value_no_signal(new_volume)
	if new_volume == volume_state:
		return
	volume_state = new_volume
	_send_command("/me/player/volume?volume_percent=%d" % new_volume, HTTPClient.METHOD_PUT)


func _on_play_pause_button_pressed() -> void:
	# Re-anchor the progress clock at its current predicted value before play_state flips,
	# so it stops/resumes advancing from exactly this point in the track.
	_set_progress_anchor(_get_predicted_progress_ms())
	if not playback_active:
		if device_list.is_empty() or %DeviceOptions.selected < 0:
			return
		play_state = true
		_set_output_device(device_list[%DeviceOptions.selected], true)
	elif play_state:
		play_state = false
		_send_command("/me/player/pause", HTTPClient.METHOD_PUT)
	else:
		play_state = true
		_send_command("/me/player/play", HTTPClient.METHOD_PUT)
	_update_progress_display()
	_schedule_song_end()


# Called once a skip command succeeds. Arms the pending-track-change guard, since Spotify's
# server-side state may not reflect the skip yet; _current_track_id is left as-is so the guard
# can tell the pre-skip track apart from a genuinely new one. Clearing the queue drops any
# further skip presses made before this response, intentionally debouncing rapid skips the
# same way the official clients do.
func _reset_state_for_skip() -> void:
	_request_queue.clear()
	_track_change_retry_timer.stop()

	_pending_track_change_from_id = _current_track_id
	_pending_track_change_since_ticks = Time.get_ticks_msec()

	_next_track_data = {}
	_set_progress_anchor(0)
	_end_timer.stop()
	_update_progress_display()

	_request_state()


func _on_track_change_retry_timer_timeout() -> void:
	_request_state()


# Called once a skip command's response arrives.
func _on_skip_command_completed(response_code: int, _data: Variant) -> void:
	if response_code < 200 or response_code >= 300:
		return
	_reset_state_for_skip()


# Below SKIP_BACK_RESTART_THRESHOLD_MS into the track this skips to the previous track, same
# as the official Spotify clients; past it, it instead restarts the current track.
func _on_skip_back_button_pressed() -> void:
	if _get_predicted_progress_ms() > SKIP_BACK_RESTART_THRESHOLD_MS:
		_seek_to(0)
	else:
		_send_skip_command("/me/player/previous")


func _on_skip_forward_button_pressed() -> void:
	_send_skip_command("/me/player/next")


func _on_repeat_button_pressed() -> void:
	repeat_state = (repeat_state + 1) % REPEAT_MODES.size()
	%RepeatButton.texture_normal = REPEAT_TEXTURES[repeat_state]
	_send_command("/me/player/repeat?state=" + REPEAT_MODES[repeat_state], HTTPClient.METHOD_PUT)
	_request_playback_queue()


func _on_shuffle_button_pressed() -> void:
	shuffle_state = not shuffle_state
	_send_command(
		"/me/player/shuffle?state=" + str(shuffle_state).to_lower(), HTTPClient.METHOD_PUT
	)
	_request_playback_queue()


func _on_volume_down_button_pressed() -> void:
	_set_volume(volume_state - VOLUME_STEP)


func _on_volume_up_button_pressed() -> void:
	_set_volume(volume_state + VOLUME_STEP)


func _on_volume_slider_drag_started() -> void:
	_volume_dragging = true


func _on_volume_slider_drag_ended(value_changed: bool) -> void:
	_volume_dragging = false
	if value_changed:
		_set_volume(int(%VolumeSlider.value))


func _on_progress_slider_drag_started() -> void:
	_progress_dragging = true


func _on_progress_slider_drag_ended(value_changed: bool) -> void:
	_progress_dragging = false
	if value_changed:
		_seek_to(int(%ProgressSlider.value))


func _on_device_options_item_selected(index: int) -> void:
	_set_output_device(device_list[index], play_state)


func _on_exited_edit_mode() -> void:
	config.save()


func _on_auth_wizard_auth_completed(
	new_encoded_client: String, new_refresh_token: String, new_access_token: String
) -> void:
	encoded_client = new_encoded_client
	refresh_token = new_refresh_token
	access_token = new_access_token
	_save_credentials()
	authenticated = true
	_update_setup_hint()
	_start_polling()


## A single Spotify api request waiting in the queue.
class SpotifyApiRequest:
	extends RefCounted

	var url: String
	var method: HTTPClient.Method = HTTPClient.METHOD_GET
	var headers: PackedStringArray = []
	var body: String = ""
	# If true the access token gets added as authorization header when the request is sent
	var use_bearer: bool = true
	# True once the request got retried after refreshing an expired access token
	var retried: bool = false
	# Called with (response_code: int, parsed_json: Variant) once the request completed
	var callback: Callable = Callable()
	# Whether a non-empty response body should be parsed as JSON for callback, see
	# _send_skip_command()
	var parse_json: bool = true


## Handles authentication setup for the spotify client.
class AuthWizard:
	extends VBoxContainer
	## Signal emitted when the authentication is complete with all the relevant infos.
	signal auth_completed(encoded_client: String, refresh_token: String, access_token: String)

	const SCOPE: String = "user-modify-playback-state user-read-playback-state user-read-currently-playing"
	const REDIRECT_URI: String = "http://127.0.0.1:8888/callback"

	var _auth_status_vbox: VBoxContainer = VBoxContainer.new()
	var _auth_status_label: Label = Label.new()
	var _setup_auth_button: Button = Button.new()

	var _new_auth_vbox: VBoxContainer = VBoxContainer.new()
	var _credentials_editor: Config.ConfigEditor
	var _credentials_creation_config: Config = Config.new()
	var _show_dev_setup_button: Button = Button.new()
	var _start_auth_button: Button = Button.new()

	var _auth_info_vbox: VBoxContainer = VBoxContainer.new()
	var _auth_info_label: RichTextLabel = RichTextLabel.new()
	var _auth_info_text_edit: LineEdit = LineEdit.new()

	var _http_server: HttpServer
	var _encoded_client: String
	var _authorization_code: String
	var _auth_request: HTTPRequest

	func _init(auth_status: bool) -> void:
		add_theme_constant_override("separation", 20)

		_auth_status_vbox.add_theme_constant_override("separation", 10)
		_auth_status_label.text = "You're authenticated"
		_setup_auth_button.text = "Authenticate new account"
		_setup_auth_button.pressed.connect(_on_setup_auth_button_pressed)
		_auth_status_vbox.add_child(_auth_status_label)
		_auth_status_vbox.add_child(_setup_auth_button)
		_auth_status_vbox.visible = auth_status
		add_child(_auth_status_vbox)

		_new_auth_vbox.add_theme_constant_override("separation", 10)
		_credentials_creation_config.add_string("Client ID", "client_id", "")
		_credentials_creation_config.add_string("Client secret", "client_secret", "")
		_credentials_editor = _credentials_creation_config.generate_editor()
		_show_dev_setup_button.text = "How do get this info?"
		_show_dev_setup_button.pressed.connect(_on_show_dev_setup_button_pressed)
		_start_auth_button.text = "Start authentication"
		_start_auth_button.pressed.connect(_on_start_auth_button_pressed)
		_new_auth_vbox.add_child(_credentials_editor)
		_new_auth_vbox.add_child(_show_dev_setup_button)
		_new_auth_vbox.add_child(_start_auth_button)
		_new_auth_vbox.visible = not _auth_status_vbox.visible
		add_child(_new_auth_vbox)

		_auth_info_vbox.add_theme_constant_override("separation", 10)
		_auth_info_label.bbcode_enabled = true
		_auth_info_label.fit_content = true
		_auth_info_label.meta_clicked.connect(_on_meta_clicked)
		_auth_info_text_edit.editable = false
		_auth_info_vbox.add_child(_auth_info_label)
		_auth_info_vbox.add_child(_auth_info_text_edit)
		_auth_info_vbox.visible = false
		add_child(_auth_info_vbox)

	## Handler for the auth callback http server
	func handle_get(request, response):
		if request.query.has("code"):
			_authorization_code = request.query["code"]
			response.send(200, "You can now close this tab and continue in DreamDeck")
			_request_authorization()
			_http_server.queue_free()
			_http_server = null
		else:
			response.send(
				200, "Something went wrong, failed to extract authorization code from request url"
			)

	func _on_setup_auth_button_pressed() -> void:
		_auth_status_vbox.visible = false
		_new_auth_vbox.visible = true

	func _on_show_dev_setup_button_pressed() -> void:
		var dev_setup_label: RichTextLabel = RichTextLabel.new()
		dev_setup_label.bbcode_enabled = true
		dev_setup_label.selection_enabled = true
		dev_setup_label.meta_clicked.connect(_on_meta_clicked)
		dev_setup_label.text = (
			"""For this you will need Spotify Premium and create a developer account.

[ol type=1]
Go to the Spotify dashboard: [color=lightblue][url]https://developer.spotify.com/dashboard/applications[/url][/color]
Click \"Create app\" in the top right
Fill out the necessary info and add \"%s\" to the \"Redirect URIs\"
Click on \"Save\"
Click on \"Settings\" in the top right
Copy your \"Client ID\" and \"Client secret\" into DreamDeck
[/ol]
"""
			% REDIRECT_URI
		)
		PopupManager.push_stack_item([dev_setup_label])

	func _on_start_auth_button_pressed() -> void:
		var abort: bool = false
		abort = not _credentials_editor.get_editor("client_id").validate("") or abort
		abort = not _credentials_editor.get_editor("client_secret").validate("") or abort
		if abort:
			return

		var creds: Dictionary = _credentials_editor.serialize()
		_encoded_client = Marshalls.utf8_to_base64(
			"%s:%s" % [creds["client_id"], creds["client_secret"]]
		)
		_setup_http_server()
		_show_auth_info(creds["client_id"])

	func _setup_http_server() -> void:
		if _http_server and is_instance_valid(_http_server):
			_http_server.free()
		_http_server = HttpServer.new()
		_http_server.set("bind_address", "127.0.0.1")
		_http_server.set("port", 8888)
		_http_server.register_router("/callback", self)
		add_child(_http_server)
		_http_server.start()

	func _request_authorization():
		var headers: Array = [
			"Content-Type: application/x-www-form-urlencoded",
			"Authorization: Basic %s" % _encoded_client
		]
		var data: String = (
			"grant_type=authorization_code&code=%s&redirect_uri=%s"
			% [_authorization_code, REDIRECT_URI]
		)
		if _auth_request and is_instance_valid(_auth_request):
			_auth_request.free()

		_auth_request = HTTPRequest.new()
		add_child(_auth_request)
		_auth_request.request_completed.connect(_on_auth_request_completed)
		_auth_request.request(
			"https://accounts.spotify.com/api/token", headers, HTTPClient.METHOD_POST, data
		)

	func _on_auth_request_completed(
		result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
	) -> void:
		if result != HTTPRequest.RESULT_SUCCESS:
			push_error("Auth request failed with result %s" % result)
			return
		if response_code != HTTPClient.RESPONSE_OK:
			push_error(
				(
					"Auth request failed with response code %s: %s"
					% [response_code, body.get_string_from_utf8()]
				)
			)
			return

		var json: JSON = JSON.new()
		var error: Error = json.parse(body.get_string_from_utf8())
		if error != OK:
			push_error("Error when parsing auth json: %s" % json.get_error_message())
			return

		if json.data.has("refresh_token"):
			auth_completed.emit(
				_encoded_client, json.data["refresh_token"], json.data["access_token"]
			)
			_hide_auth_setup()

		_auth_request.queue_free()
		_auth_request = null

	func _show_auth_info(client_id: String) -> void:
		var auth_link: String = _create_auth_link(client_id)
		_auth_info_label.text = (
			"Click this [color=lightblue][b][url=%s]link[/url][/b][/color]\nor copy the link below into your browser."
			% auth_link
		)
		_auth_info_text_edit.text = auth_link
		_auth_info_vbox.visible = true

	func _hide_auth_setup() -> void:
		_new_auth_vbox.visible = false
		_auth_info_vbox.visible = false
		_auth_info_label.text = ""
		_auth_info_text_edit.text = ""

		_auth_status_vbox.visible = true

	func _create_auth_link(client_id: String) -> String:
		return (
			"https://accounts.spotify.com/authorize?client_id=%s&response_type=code&scope=%s&redirect_uri=%s"
			% [client_id, SCOPE, REDIRECT_URI]
		)

	func _on_meta_clicked(meta: Variant) -> void:
		OS.shell_open(str(meta))
