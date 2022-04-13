extends Button

export var app: String
export var arguments: PoolStringArray
export var app_name: String
export var icon_path: String
export var straight_shell: bool = false
export var show_app_name: bool = false

var final_arguments: PoolStringArray

func _ready():
	apply_change()

func apply_change():
	final_arguments = arguments
	if !straight_shell:
		final_arguments.insert(0, app)
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

func set_logo():
	if icon_path:
		var complete_icon_path = "user://icons/" + icon_path
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

func show_name_with_icon():
	$Icon.margin_bottom = -50
	$Icon.margin_left = 35
	$Icon.margin_right = -35
	$AppName.text = app_name
	$AppName.visible = true

func _on_AppButton_pressed():
	if straight_shell:
		OS.execute(app, final_arguments, false)
	else:
		OS.execute("nohup", final_arguments, false)

func save():
	var save_dict = {
		"app" : app,
		"arguments" : arguments,
		"app_name" : app_name,
		"icon_path" : icon_path,
		"straight_shell" : straight_shell,
		"show_app_name" : show_app_name
	}
	return save_dict
