extends Node

@onready var _layout: Layout = get_node("/root/Main/Layout")
var _switch_panel_config: Config = Config.new()
var _available_panels: Array[String] = []
var _actions: Array[PluginCoordinator.PluginActionDefinition]


## Returns all Dreamdeck builtin actions
func get_actions() -> Array[PluginCoordinator.PluginActionDefinition]:
	if not _actions:
		_setup_actions()

	return _actions


## Waits [param time]. Function for builtin action "Timer"
func wait_time(time: float) -> void:
	await get_tree().create_timer(time).timeout


# TODO doesn't really work with blocking
## Executes [param command]. Function for builtin action "Execute Command"
func exec_cmd(command: String) -> bool:
	# Platform specific
	# If the os is windows we have to run commands like this:
	# OS.execute("CMD.exe", ["/c", ...])
	if OS.get_name() == "Windows":
		command = "CMD.exe /c " + command

	if ConfigLoader.get_config()["Debug"]:
		var process = ProcessNode.new()
		process.connect("stdout", _on_process_stdout)
		process.connect("stderr", _on_process_stderr)
		process.connect("finished", _on_process_finished)
		process.set("cmd", _text_to_args(command)[0])
		var args = _text_to_args(command)
		args.remove_at(0)
		process.set("args", args as PackedStringArray)
		self.add_child(process)
		var ret = process.start()
		# Error happened
		if ret:
			_print_dbg_msg(command, "error occurred: " + ret, "red")
			return false
	else:
		var args = _text_to_args(command)
		args.remove_at(0)
		return OS.create_process(_text_to_args(command)[0], args) != -1

	return true


func switch_panel(panel_name: String) -> bool:
	return _layout.show_panel_by_name(panel_name)


func update_available_panels(panels: Array[String]) -> void:
	_available_panels = panels
	var panel_object: Config.StringArrayObject = _switch_panel_config.get_object("Panel name")
	if panel_object:
		panel_object.set_string_array(panels)


func _setup_actions() -> void:
	var exec_cmd_args_config: Config = Config.new()
	exec_cmd_args_config.add_string("Command", "")
	var timer_args_config: Config = Config.new()
	timer_args_config.add_float("Time", 1.0)
	_switch_panel_config.add_string_array("Panel name", "", _available_panels)

	_actions = [
		PluginCoordinator.PluginActionDefinition.new("Execute command", "exec_cmd", "Execute a command on this device", exec_cmd_args_config, "DreamDeck", ""),
		PluginCoordinator.PluginActionDefinition.new("Timer", "wait_time", "Delays the execution of the next action by configured time in seconds", timer_args_config, "DreamDeck", ""),
		PluginCoordinator.PluginActionDefinition.new("Switch panel", "switch_panel", "Show the panel with the configured name", _switch_panel_config, "DreamDeck", "")
		]


# TODO will probably be replaced in the future by some sort of custom logger
func _print_dbg_msg(cmd: String, msg: String, color_code: String = "white"):
	# The second color code is there because when msg contains newlines the color delimiter seems to break
	# and be written as plain text into the output.
	# To circumvent this we just print a white color again before the delimiter
	print_rich("[color=" + color_code + "]" + Time.get_datetime_string_from_system() + " \"" + cmd + "\": " + msg + "[color=white][/color]")


# Creates an Array of Strings from a single String.
func _text_to_args(args) -> Array:
	return args.split(" ")


func _on_process_stdout(stdout: PackedByteArray, command: String, args: PackedStringArray):
	for arg in args:
		command += " " + arg

	_print_dbg_msg(command, stdout.get_string_from_utf8())


func _on_process_stderr(stderr: PackedByteArray, command: String, args: PackedStringArray):
	for arg in args:
		command += " " + arg

	_print_dbg_msg(command, stderr.get_string_from_utf8(), "yellow")


func _on_process_finished(err_code: int, command: String, args: PackedStringArray):
	for arg in args:
		command += " " + arg

	if err_code:
		_print_dbg_msg(command, "exited with code: " + str(err_code), "red")
	else:
		_print_dbg_msg(command, "exited with code: success", "green")
