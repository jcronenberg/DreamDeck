extends Button
class_name AppButton

@export var app: String
@export var arguments: PackedStringArray
@export var app_name: String
@export var icon_path: String
@export var show_app_name: bool = false
@export var ssh_client: String = ""

# Variables that are used for dragging in edit mode
const lifted_cooldown := 0.4 # Time in seconds before button gets lifted
var lifted = false
var lift_timer := 0.0

# Global nodes
@onready var config_loader = get_node("/root/ConfigLoader")
@onready var global_signals = get_node("/root/GlobalSignals")
@onready var plugin_coordinator := get_node("/root/PluginCoordinator")
@onready var ssh_controller

func _ready():
	set_process_input(false)
	set_process(false)
	load_ssh_controller()

	apply_change()


# We need to keep track of global input events when the button is being dragged,
# because we reparent and that has the effect of losing the pressed down state.
# To work around that, we watching global input for a button up event.
# When that gets triggered we can trigger the _on_button_up function ourselves.
func _input(event):
	if not lifted:
		set_process_input(false)
	if event is InputEventMouseButton:
		if event.pressed == false:
			_on_button_up()
			set_process_input(false)


func _process(delta):
	# Lifted countdown
	if lift_timer + delta > lifted_cooldown:
		# See _input function for explanation
		set_process_input(true)
		# Reparent so we can replace the button with an empty one
		# and also to keep getting gui_input events when moving to another row
		reparent(get_node("../../.."))
		lifted = true
		set_process(false)
	else:
		lift_timer += delta


func apply_change():
	if icon_path:
		set_image()
	elif app_name:
		text = app_name
	else:
		text = app

	if show_app_name:
		show_name_with_icon()
	else:
		show_only_icon()

	# Platform specific
	# If the os is windows we have to run commands like this:
	# OS.execute("CMD.exe", ["/c", ...])
	if OS.get_name() == "Windows":
		var args = ["/c", app]
		app = "CMD.exe"
		for arg in arguments:
			args.append(arg)
			arguments = args


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


func load_ssh_controller():
	ssh_controller = plugin_coordinator.get_plugin_loader("ssh")
	if ssh_controller:
		ssh_controller = ssh_controller.get_controller()


func _on_AppButton_pressed():
	# If we are in edit mode we don't execute the command, but instead
	# open the prompt to edit this button
	if global_signals.get_edit_state():
		var macroboard = get_parent()
		while macroboard.name != "Macroboard":
			macroboard = macroboard.get_parent()

		macroboard.edit_button(self)
		return

	if not ssh_client.is_empty():
		# Check for valid ssh_controller
		if not ssh_controller:
			load_ssh_controller()
			if not ssh_controller:
				push_error("Couldn't execute on SSH Client %s" % ssh_client)
				return

		# Some hacky stuff to format the cmd better
		# TODO remove when app and argument are combined into one
		ssh_controller.exec_on_client(ssh_client, app +
			("" if arguments.size() == 0
				or arguments.size() == 1
				and arguments[0] == "" else
			 " " + array_to_string(arguments)))

	elif config_loader.get_config()["Debug"]:
		var process = ProcessNode.new()
		process.connect("stdout", Callable(self, "_on_process_stdout"))
		process.connect("stderr", Callable(self, "_on_process_stderr"))
		process.connect("finished", Callable(self, "_on_process_finished"))
		process.set("cmd", app)
		process.set("args", arguments as PackedStringArray)
		self.add_child(process)
		var ret = process.start()
		# Error happened
		if ret:
			print_debug_msg(app, arguments, "error occurred: " + ret, "red")

	else:
		OS.create_process(app, arguments)


func _on_process_stdout(stdout: PackedByteArray, cmd: String, args: PackedStringArray):
	print_debug_msg(cmd, args, stdout.get_string_from_utf8())

func _on_process_stderr(stderr: PackedByteArray, cmd: String, args: PackedStringArray):
	print_debug_msg(cmd, args, stderr.get_string_from_utf8(), "yellow")

func _on_process_finished(err_code: int, cmd: String, args: PackedStringArray):
	if err_code:
		print_debug_msg(cmd, args, "exited with code: " + str(err_code), "red")
	else:
		print_debug_msg(cmd, args, "exited with code: success", "green")


## Prints a formatted error msg
## TODO will probably be replaced in the future by some sort of custom logger
func print_debug_msg(cmd: String, args: PackedStringArray, msg: String, color_code: String = "white"):
	# The second color code is there because when msg contains newlines the color delimiter seems to break
	# and be written as plain text into the output.
	# To circumvent this we just print a white color again before the delimiter
	print_rich("[color=" + color_code + "]" + Time.get_datetime_string_from_system() + " \"" + cmd + ("" if args.size() == 0 or args.size() == 1 and args[0] == "" else " " + array_to_string(args)) + "\": " + msg + "[color=white][/color]")


## Creates a single [String] from an [Array] of [String]s.
func array_to_string(array) -> String:
	var ret = ""
	for arg in array:
		ret += arg + " "

	ret = ret.erase(ret.length() - 1, 1)
	return ret

func save():
	var save_dict = {
		"app" : app,
		"arguments" : arguments,
		"app_name" : app_name,
		"icon_path" : icon_path,
		"show_app_name" : show_app_name,
		"ssh_client": ssh_client,
	}
	return save_dict


# TODO right now when the mouse is moved too fast, the cursor "loses" the button and we don't receive events
# until the cursor enters the button area again. This can be circumvented by using global input
# but the problem with global input is that position is also global and to macroboard relative
# so we would need to get macroboard position and deduct that from input position
func _on_gui_input(event):
	# When lifted, update position to cursor position
	if lifted and (event is InputEventMouseMotion or event is InputEventMouseButton):
		# Mouse is supposed to be at the center, so we deduct half of size
		position += event.position - size / 2
		# handle_lifted_button expects cursor position, so we need to add half of size again
		# note that we can't use event.position, because it is relative to button and not macroboard
		# which handle_lifted_button expects
		get_parent().handle_lifted_button(position + size / 2, self)


# Reset all dragging variables/states
func _on_button_up():
	if lifted:
		lifted = false
		get_parent().place_button(self)
	lift_timer = 0.0
	set_process(false)
	set_process_input(true)


# Function that when in edit mode activates the lift_timer
# (or in this case the process function)
func _on_button_down():
	if not global_signals.get_edit_state():
		return
	if not lifted:
		set_process(true)
