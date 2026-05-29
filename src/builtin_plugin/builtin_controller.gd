## Plugin controller for the builtin functions
class_name BuiltinController
extends PluginControllerBase

var _process_pool: Dictionary = {}


func _init() -> void:
	plugin_name = "DreamDeck"


func _process(_delta: float) -> void:
	for process: CommandProcess in _process_pool:
		for thread: Thread in _process_pool[process]:
			if not thread.is_alive():
				thread.wait_to_finish()
				_process_pool[process].erase(thread)

		if _process_pool[process].size() == 0:
			process.print_exit_code()
			_process_pool.erase(process)


func wait_time(_blocking: bool, time: float) -> void:
	await get_tree().create_timer(time).timeout


func exec_cmd(blocking: bool, command: String) -> bool:
	if OS.get_name() == "Windows":
		command = "CMD.exe /c " + command

	if blocking:
		var args: Array = split_command(command)
		var cmd: String = args[0]
		args.remove_at(0)
		var output: Array = []
		var ret: int = OS.execute(cmd, args, output, true)
		if ConfigLoader.get_config()["debug"]:
			if output.size() > 0 and output[0] != "":
				print_dbg_msg(command, output[0])
			print_dbg_msg(command, "exited with code: %s" % ret, "red" if ret != 0 else "white")
		return ret != -1

	if ConfigLoader.get_config()["debug"]:
		var cmd_proc := CommandProcess.new(command)
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


func switch_panel(_blocking: bool, panel_name: String) -> bool:
	if not PluginCoordinator.layout:
		return false
	return PluginCoordinator.layout.show_panel_by_name(panel_name)


static func print_dbg_msg(command: String, msg: String, color_code: String = "white") -> void:
	print_rich(
		(
			'[color=%s]%s "%s": %s[color=white][/color]'
			% [color_code, Time.get_datetime_string_from_system(), command, msg]
		)
	)


static func split_command(command: String) -> Array:
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


class CommandProcess:
	var command: String
	var _pid: int = -1

	func _init(init_command: String) -> void:
		command = init_command

	func exec_cmd() -> Array[Thread]:
		@warning_ignore("static_called_on_instance")
		var args: Array = BuiltinController.split_command(command)
		var cmd: String = args[0]
		args.remove_at(0)
		var process: Dictionary = OS.execute_with_pipe(cmd, args)
		if process == {}:
			@warning_ignore("static_called_on_instance")
			BuiltinController.print_dbg_msg(command, "Failed to execute", "red")
			return []

		_pid = process["pid"]
		var threads: Array[Thread] = []
		for fd in ["stdio", "stderr"]:
			var thread := Thread.new()
			thread.start(_read.bind(process[fd], "white" if fd == "stdio" else "yellow"))
			threads.append(thread)

		return threads

	func print_exit_code() -> void:
		if _pid < 0:
			@warning_ignore("static_called_on_instance")
			BuiltinController.print_dbg_msg(command, "failed to start", "red")
			return

		var exit_code: int = OS.get_process_exit_code(_pid)
		@warning_ignore("static_called_on_instance")
		BuiltinController.print_dbg_msg(
			command, "exited with code %s" % exit_code, "red" if exit_code != 0 else "green"
		)

	func _read(file: FileAccess, color_code: String = "white") -> void:
		if is_instance_valid(file):
			while file.is_open() and file.get_error() == OK:
				var line: String = file.get_line()
				if line != "":
					@warning_ignore("static_called_on_instance")
					BuiltinController.print_dbg_msg(command, line, color_code)
