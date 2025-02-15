## Handler for all the builtin actions.
extends Node

var _layout: Layout  # Meant to be set by Layout itself
var _switch_panel_config: Config = Config.new()
var _available_panels: Array[String] = []
var _actions: Array[PluginCoordinator.PluginActionDefinition]
# Each process in debug mode is supposed to have the [CommandProcess]
# as the key and the threads where stdio and stderr are monitored as the value.
var _process_pool: Dictionary = {}


func _process(_delta: float) -> void:
	for process: CommandProcess in _process_pool:
		for thread: Thread in _process_pool[process]:
			if not thread.is_alive():
				thread.wait_to_finish()
				_process_pool[process].erase(thread)

		if _process_pool[process].size() == 0:
			process.print_exit_code()
			_process_pool.erase(process)


## Returns all Dreamdeck builtin actions.
func get_actions() -> Array[PluginCoordinator.PluginActionDefinition]:
	if not _actions:
		_setup_actions()

	return _actions


## Waits [param time]. Function for builtin action "Timer".
func wait_time(time: float) -> void:
	await get_tree().create_timer(time).timeout


# TODO doesn't really work with blocking
## Executes [param command]. Function for builtin action "Execute Command".
func exec_cmd(command: String) -> bool:
	# Platform specific
	# If the os is windows we have to run commands like this:
	# OS.execute("CMD.exe", ["/c", ...])
	if OS.get_name() == "Windows":
		command = "CMD.exe /c " + command

	if ConfigLoader.get_config()["debug"]:
		var cmd_proc: CommandProcess = CommandProcess.new(command)
		var threads: Array[Thread] = cmd_proc.exec_cmd()
		if threads.size() == 0:
			cmd_proc.print_exit_code()
			return false
		_process_pool[cmd_proc] = threads
	else:
		var args: Array = split_command(command)
		var cmd: String = args[0]
		args.remove_at(0)
		return OS.create_process(cmd, args) != -1

	return true


## Switches panel [param panel_name] to the foreground. Function for builtin action "Switch panel".
func switch_panel(panel_name: String) -> bool:
	return _layout.show_panel_by_name(panel_name)


## Updates all available panels. This is used to display a selection of panels in the action editor.
## This is mostly supposed to be called by [Layout] when it loads or something has changed.
func update_available_panels(panels: Array[String]) -> void:
	_available_panels = panels
	var panel_object: Config.StringArrayObject = _switch_panel_config.get_object("panel_name")
	if panel_object:
		panel_object.set_string_array(panels)
		if panels.size() > 0:
			panel_object.set_default_value(panels[0])
			panel_object.set_value(panels[0])


func _setup_actions() -> void:
	var exec_cmd_args_config: Config = Config.new()
	exec_cmd_args_config.add_string("Command", "command", "")
	var timer_args_config: Config = Config.new()
	timer_args_config.add_float("Time", "time", 1.0)
	var default_panel: String = "" if _available_panels.size() == 0 else _available_panels[0]
	_switch_panel_config.add_string_array(
		"Panel name", "panel_name", default_panel, _available_panels
	)

	_actions = [
		PluginCoordinator.PluginActionDefinition.new(
			"Execute command",
			"exec_cmd",
			"Execute a command on this device",
			exec_cmd_args_config,
			"DreamDeck",
			""
		),
		PluginCoordinator.PluginActionDefinition.new(
			"Timer",
			"wait_time",
			"Delays the execution of the next action by configured time in seconds",
			timer_args_config,
			"DreamDeck",
			""
		),
		PluginCoordinator.PluginActionDefinition.new(
			"Switch panel",
			"switch_panel",
			"Show the panel with the configured name",
			_switch_panel_config,
			"DreamDeck",
			""
		)
	]


## Creates an array of strings from a single command string.
## It also does some basic parsing of quoted strings and escaped characters within the command
## to make quoted strings a single string in the array.
## E.g. "a 'quoted string' or escaped\\ char in \"a command\"" would result in
## ["a", "quoted string", "or", "escaped char", "in", "a command"]
## Further parsing may be needed to give a user the full capabilities of the shell,
## but this comes close enough IMO and for really complex stuff a shell script is the preferred
## option anyway.
static func split_command(command: String) -> Array:
	# If no quoted strings are in command simply use split()
	if not command.contains('"') and not command.contains("'") and not command.contains("\\"):
		return command.split(" ")

	var args: Array[String] = []
	var current_arg: String = ""
	var quote_char: String
	var in_quotes: bool = false
	var escape_next: bool = false

	for c in command:
		if escape_next:
			current_arg += c
			escape_next = false
		elif c == "\\":
			escape_next = true
		elif c == '"' or c == "'":
			if in_quotes:
				if c == quote_char:
					in_quotes = false
				else:
					current_arg += c
			else:
				in_quotes = true
				quote_char = c
		elif c == " " and not in_quotes:
			if current_arg != "":
				args.append(current_arg)
				current_arg = ""
		else:
			current_arg += c

	args.append(current_arg)
	return args


## Helper class that allows async printing of a command
##
## Uses [method OS.execute_with_pipe] to achieve this and sets up 2 threads that monitor and print
## stdio and stderr.
class CommandProcess:
	## The command string.
	var command: String

	var _pid: int = -1

	func _init(init_command: String):
		command = init_command

	## Executes the [member command].[br]
	## Returns 2 threads that monitor and print stdio and stderr of the [member command].
	func exec_cmd() -> Array[Thread]:
		@warning_ignore("static_called_on_instance")
		var args: Array = DreamdeckBuiltinActions.split_command(command)
		var cmd: String = args[0]
		args.remove_at(0)
		var process: Dictionary = OS.execute_with_pipe(cmd, args)
		if process == {}:
			_print_dbg_msg("Failed to execute", "red")
			return []

		_pid = process["pid"]
		var threads: Array[Thread] = []
		for fd in ["stdio", "stderr"]:
			var thread: Thread = Thread.new()
			thread.start(_read.bind(process[fd], "white" if fd == "stdio" else "yellow"))
			threads.append(thread)

		return threads

	## Prints the exit code nicely formatted or an error message if it was never started.
	func print_exit_code() -> void:
		if _pid < 0:
			_print_dbg_msg("failed to start", "red")
			return

		var exit_code: int = OS.get_process_exit_code(_pid)
		_print_dbg_msg("exited with code %s" % exit_code, "red" if exit_code != 0 else "green")

	func _read(file: FileAccess, color_code: String = "white") -> void:
		if is_instance_valid(file):
			while file.is_open() and file.get_error() == OK:
				var line: String = file.get_line()
				if line != "":
					_print_dbg_msg(line, color_code)

	func _print_dbg_msg(msg: String, color_code: String = "white"):
		# The second color code is there because when msg contains newlines the color delimiter seems to break
		# and be written as plain text into the output.
		# To circumvent this we just print a white color again before the delimiter
		print_rich(
			(
				'[color=%s]%s "%s": %s[color=white][/color]'
				% [color_code, Time.get_datetime_string_from_system(), command, msg]
			)
		)
