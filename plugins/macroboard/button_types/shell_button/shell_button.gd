class_name ShellButton
extends MacroButton

@export var command: String
@export var app_name: String
@export var icon_path: String
@export var show_app_name: bool = false
@export var ssh_client: String = ""

# Global nodes
@onready var config_loader = get_node("/root/ConfigLoader")
@onready var plugin_coordinator := get_node("/root/PluginCoordinator")
@onready var ssh_controller

#func _init():
# 	button_type = "shell_button"


func _ready():
	super()
	_load_ssh_controller()

	apply_change()


func save():
	var save_dict = {
		# "button_type" : button_type,
		"command" : command,
		"app_name" : app_name,
		"icon_path" : icon_path,
		"show_app_name" : show_app_name,
		"ssh_client": ssh_client,
	}
	return save_dict


func apply_change():
	if icon_path:
		set_image()
	elif app_name:
		text = app_name
	else:
		text = command

	if show_app_name:
		show_name_with_icon()
	else:
		show_only_icon()

	# Platform specific
	# If the os is windows we have to run commands like this:
	# OS.execute("CMD.exe", ["/c", ...])
	if OS.get_name() == "Windows" and ssh_client.is_empty():
		command = "CMD.exe /c " + command


func set_image():
	if icon_path:
		var complete_icon_path = config_loader.get_conf_dir() + "icons/" + icon_path
		var image = Image.load_from_file(complete_icon_path)
		$Icon.texture = ImageTexture.create_from_image(image)


func show_only_icon():
	$Icon.offset_bottom = -20
	$Icon.offset_left = 20
	$Icon.offset_right = -20
	$AppName.visible = false
	$AppName.set_autowrap_mode(true)


func show_name_with_icon():
	$Icon.offset_bottom = -50
	$Icon.offset_left = 35
	$Icon.offset_right = -35
	$AppName.text = app_name
	$AppName.visible = true


func _on_AppButton_pressed():
	# If we are in edit mode we don't execute the command, but instead
	# open the prompt to edit this button
	if _global_signals.get_edit_state():
		var macroboard = get_parent()
		while macroboard.name != "Macroboard":
			macroboard = macroboard.get_parent()

		macroboard.edit_button(self)
		return

	if not ssh_client.is_empty():
		# Check for valid ssh_controller
		if not ssh_controller:
			_load_ssh_controller()
			if not ssh_controller:
				push_error("Couldn't execute on SSH Client %s" % ssh_client)
				return

		# Some hacky stuff to format the cmd better
		# TODO remove when app and argument are combined into one
		ssh_controller.exec_on_client(ssh_client, command)

	elif config_loader.get_config()["Debug"]:
		var process = ProcessNode.new()
		process.connect("stdout", Callable(self, "_on_process_stdout"))
		process.connect("stderr", Callable(self, "_on_process_stderr"))
		process.connect("finished", Callable(self, "_on_process_finished"))
		process.set("cmd", _text_to_args(command)[0])
		var args = _text_to_args(command)
		args.remove_at(0)
		process.set("args", args as PackedStringArray)
		self.add_child(process)
		var ret = process.start()
		# Error happened
		if ret:
			_print_dbg_msg(command, "error occurred: " + ret, "red")

	else:
		var args = _text_to_args(command)
		args.remove_at(0)
		OS.create_process(_text_to_args(command)[0], args)


func _load_ssh_controller():
	ssh_controller = plugin_coordinator.get_plugin_loader("ssh")
	if ssh_controller:
		ssh_controller = ssh_controller.get_controller()


# TODO will probably be replaced in the future by some sort of custom logger
func _print_dbg_msg(cmd: String, msg: String, color_code: String = "white"):
	# The second color code is there because when msg contains newlines the color delimiter seems to break
	# and be written as plain text into the output.
	# To circumvent this we just print a white color again before the delimiter
	print_rich("[color=" + color_code + "]" + Time.get_datetime_string_from_system() + " \"" + cmd + "\": " + msg + "[color=white][/color]")


# Creates an Array of Strings from a single String.
func _text_to_args(args) -> Array:
	return args.split(" ")


func _on_process_stdout(stdout: PackedByteArray, _cmd: String, _args: PackedStringArray):
	_print_dbg_msg(command, stdout.get_string_from_utf8())


func _on_process_stderr(stderr: PackedByteArray, _cmd: String, _args: PackedStringArray):
	_print_dbg_msg(command, stderr.get_string_from_utf8(), "yellow")


func _on_process_finished(err_code: int, _cmd: String, _args: PackedStringArray):
	if err_code:
		_print_dbg_msg(command, "exited with code: " + str(err_code), "red")
	else:
		_print_dbg_msg(command, "exited with code: success", "green")
