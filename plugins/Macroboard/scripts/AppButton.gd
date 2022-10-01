extends Button

export var app: String
export var arguments: PoolStringArray
export var app_name: String
export var icon_path: String
export var show_app_name: bool = false

# Global nodes
onready var config_loader = get_node("/root/ConfigLoader")


func _ready():
	apply_change()

func apply_change():
	if icon_path:
		set_logo()
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


func set_logo():
	if icon_path:
		var complete_icon_path = config_loader.get_conf_dir() + "icons/" + icon_path
		var image = Image.new()
		image.load(complete_icon_path)
		var texture = ImageTexture.new()
		texture.create_from_image(image)
		$Icon.texture = texture

func show_only_icon():
	$Icon.margin_bottom = -20
	$Icon.margin_left = 20
	$Icon.margin_right = -20
	$AppName.visible = false
	$AppName.autowrap = true

func show_name_with_icon():
	$Icon.margin_bottom = -50
	$Icon.margin_left = 35
	$Icon.margin_right = -35
	$AppName.text = app_name
	$AppName.visible = true

func _on_AppButton_pressed():
# warning-ignore:return_value_discarded
	OS.execute(app, arguments, false)

func save():
	var save_dict = {
		"app" : app,
		"arguments" : arguments,
		"app_name" : app_name,
		"icon_path" : icon_path,
		"show_app_name" : show_app_name
	}
	return save_dict
