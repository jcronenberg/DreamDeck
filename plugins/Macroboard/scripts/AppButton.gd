extends Button

@export var app: String
@export var arguments: PackedStringArray
@export var app_name: String
@export var icon_path: String
@export var show_app_name: bool = false

# Global nodes
@onready var config_loader = get_node("/root/ConfigLoader")
@onready var global_signals = get_node("/root/GlobalSignals")


func _ready():
	apply_change()


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


func _on_AppButton_pressed():
	# If we are in edit mode we don't execute the command, but instead
	# open the prompt to edit this button
	if global_signals.get_edit_state():
		var macroboard = get_parent()
		while macroboard.name != "Macroboard":
			macroboard = macroboard.get_parent()

		macroboard.edit_button(self)
		return

	OS.create_process(app, arguments)

func save():
	var save_dict = {
		"app" : app,
		"arguments" : arguments,
		"app_name" : app_name,
		"icon_path" : icon_path,
		"show_app_name" : show_app_name
	}
	return save_dict
