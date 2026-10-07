class_name ClaudeStatusSceneBase
extends PluginSceneBase
## Base for scenes showing the status json that Claude Code hooks keep up to date. Polls the
## file, either locally or through a client of the SSH plugin, and hands its parsed content to
## [method _show_status].

const DEFAULT_STATUS_FILE: String = "$HOME/.claude/status.json"
const POLL_INTERVAL: float = 1.0
# Wait after a failed SSH connection, so an unreachable host doesn't get a connection attempt
# (and error) every poll.
const SSH_RETRY_INTERVAL_MS: int = 10000

var _status_file: String = ""
var _use_ssh: bool = false
var _ssh_client_uuid: Variant = null
# Raw content of the last read, to skip reparsing and relayouting when nothing changed.
var _last_content: String = ""

var _ssh_thread: Thread = null
# Bumped on config changes, so replies to requests made with an older config get dropped.
var _ssh_request_id: int = 0
var _ssh_retry_after_ticks: int = 0

var _poll_timer: Timer


func _init() -> void:
	config.add_file_path(
		"Status file",
		"status_file",
		DEFAULT_STATUS_FILE,
		(
			"The json file the status is read from. "
			+ "[code]$HOME[/code] and [code]~[/code] are expanded. "
			+ "When reading via SSH, this is the path on the SSH client's machine"
		),
		["*.json"]
	)
	config.add_bool(
		"Read via SSH",
		"use_ssh",
		false,
		"Read the status file through a client of the SSH plugin instead of locally"
	)
	config.add_dict("SSH client", "ssh_client", null, {})


# Subclasses build their UI before calling this, since it applies the config.
func _ready() -> void:
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.timeout.connect(_refresh)
	add_child(_poll_timer)
	_poll_timer.start()

	super()


func _notification(what: int) -> void:
	# Waiting in _exit_tree instead would also block whenever the panel is just moved.
	if what == NOTIFICATION_PREDELETE and _ssh_thread:
		_ssh_thread.wait_to_finish()


# The SSH plugin's clients may not be loaded yet at this point, and Config rejects a saved
# client that isn't among the options, so the saved one is let through as is. The options get
# their proper names in edit_config().
func _init_config() -> void:
	var saved: Variant = ConfLib.load_config(conf_dir.path_join("config.json"))
	if saved is Dictionary and saved.get("ssh_client") is String:
		config.get_object("ssh_client").set_dict({saved["ssh_client"]: saved["ssh_client"]})
	super()


func edit_config() -> void:
	_update_ssh_client_options()
	var config_editor: Config.ConfigEditor = config.generate_editor()
	# Still shown while enabled, so it can be turned off after the SSH plugin was disabled.
	if not _get_ssh_controller() and not _use_ssh:
		config_editor.get_editor("use_ssh").visible = false
		config_editor.get_editor("ssh_client").visible = false

	PopupManager.init_popup(
		[config_editor],
		func apply_and_save() -> void:
			config_editor.apply()
			config_editor.save()
	)


# Subclasses read their own settings before calling this, since it triggers a refresh.
func handle_config() -> void:
	var data: Dictionary = config.get_as_dict()
	_status_file = data["status_file"]
	_use_ssh = data["use_ssh"]
	_ssh_client_uuid = data["ssh_client"]
	_ssh_request_id += 1
	_ssh_retry_after_ticks = 0

	# Config also gets loaded (and emits config_changed) before _ready built the UI.
	if not _poll_timer:
		return

	_last_content = ""
	_refresh()


func scene_show() -> void:
	super()
	if _poll_timer:
		_poll_timer.start()
		_refresh()


func scene_hide() -> void:
	super()
	if _poll_timer:
		_poll_timer.stop()


## Called with the parsed status file whenever its content changed.
func _show_status(_status: Dictionary) -> void:
	pass


## Called instead of [method _show_status] when there is no status to show.
func _show_hint(_message: String) -> void:
	pass


func _refresh() -> void:
	if _use_ssh:
		_refresh_ssh()
	else:
		_refresh_local()


func _refresh_local() -> void:
	var path: String = _expand_home(_status_file)
	if not FileAccess.file_exists(path):
		_show_error("Status file not found:\n%s" % path)
		return

	_apply_content(FileAccess.get_file_as_string(path))


func _refresh_ssh() -> void:
	if _ssh_thread:
		if _ssh_thread.is_alive():
			return
		_ssh_thread.wait_to_finish()
		_ssh_thread = null

	if Time.get_ticks_msec() < _ssh_retry_after_ticks:
		return

	var controller: PluginControllerBase = _get_ssh_controller()
	if not controller:
		_show_error("Reading via SSH requires the SSH plugin to be enabled")
		return

	var client: Object = null
	if _ssh_client_uuid is String:
		client = controller.call("get_client", _ssh_client_uuid)
	if not client:
		_show_error("No SSH client selected")
		return

	var cmd: String = "cat -- %s" % _to_remote_path_arg(_status_file)
	_ssh_thread = Thread.new()
	_ssh_thread.start(_read_via_ssh.bind(client.call("get_client"), cmd, _ssh_request_id))


# Runs on _ssh_thread, since connecting and executing block.
func _read_via_ssh(ssh_client: Object, cmd: String, request_id: int) -> void:
	var result: Variant = ssh_client.call("exec_blocking", cmd)
	_on_ssh_read.call_deferred(result, request_id)


func _on_ssh_read(result: Variant, request_id: int) -> void:
	if request_id != _ssh_request_id:
		return

	if not result is Dictionary:
		_ssh_retry_after_ticks = Time.get_ticks_msec() + SSH_RETRY_INTERVAL_MS
		_show_error("Failed to connect via SSH")
		return

	if result["exit_status"] != 0:
		var stderr: String = str(result["stderr"]).strip_edges()
		_show_error("Failed to read status file via SSH:\n%s" % stderr)
		return

	_apply_content(result["stdout"])


func _apply_content(content: String) -> void:
	if content == _last_content:
		return
	_last_content = content

	# The file is replaced atomically by the hooks, so a parse failure is a genuinely
	# malformed file rather than a half-written one.
	var json: JSON = JSON.new()
	if json.parse(content) != OK or not json.data is Dictionary:
		_show_hint("Failed to parse status file")
		return

	_show_status(json.data)


func _show_error(message: String) -> void:
	_last_content = ""
	_show_hint(message)


# Not typed as SSHController, as that script fails to compile without the SSH plugin's Rust
# library and would then take this script down with it.
func _get_ssh_controller() -> PluginControllerBase:
	var loader: PluginLoaderBase = PluginCoordinator.get_plugin_loader("SSH")
	return loader.get_controller("SSHController") if loader else null


func _update_ssh_client_options() -> void:
	var options: Dictionary = {}
	var controller: PluginControllerBase = _get_ssh_controller()
	if controller:
		options = controller.call("get_clients")

	var client_object: Config.DictObject = config.get_object("ssh_client")
	var current: Variant = client_object.get_value()
	if current != null and not options.values().has(current):
		options["Unknown client (%s)" % current] = current
	client_object.set_dict(options)


# Double quoted, so $HOME (and ~, rewritten to it) still expand on the remote machine.
static func _to_remote_path_arg(path: String) -> String:
	if path.begins_with("~"):
		path = "$HOME" + path.substr(1)
	for special in ["\\", "\"", "`"]:
		path = path.replace(special, "\\" + special)
	return "\"%s\"" % path


static func _expand_home(path: String) -> String:
	var home: String = OS.get_environment("HOME")
	if home.is_empty():
		home = OS.get_environment("USERPROFILE")

	if path.begins_with("~"):
		path = home + path.substr(1)
	return path.replace("$HOME", home)
