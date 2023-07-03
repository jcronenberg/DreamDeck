extends PopupPanel

const TWEEN_SPEED := 0.5
const MAX_MENU_MARGIN: float = 400.0

onready var setting_button := load("res://scenes/MainMenu/SubmenuButton.tscn")


func show_menu():
	rect_size.x = 0.0
	visible = true
	var tween = tween_menu(MAX_MENU_MARGIN)
	set_menu_button_border_width(8)
	get_node("../ExitAreaButton").visible = true
	yield(tween, "finished")
	set_min_size(MAX_MENU_MARGIN)

	# TODO there probably is a better place for this or even a smarter way
	# For these buttons we need to set clip_text because otherwise
	# the fading out wouldn't work smoothly
	# Shouldn't be an issue because the names of these buttons should
	# not be changeable anyway
	for child in $SettingSeparator.get_children():
		child.clip_text = true


func hide_menu():
	get_node("/root/GlobalSignals").config_changed()
	for child in $SettingSeparator.get_children():
		if child.has_method("hide_submenu"):
			child.hide_submenu()
	set_menu_button_border_width(0)
	set_min_size(0.0)
	rect_size.x = MAX_MENU_MARGIN
	var tween = tween_menu(0.0)
	yield(tween, "finished")
	get_node("../ExitAreaButton").visible = false
	visible = false


func tween_menu(final_val):
	var tween := create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.set_parallel()
	tween.tween_property(self, "rect_size:x", final_val, TWEEN_SPEED)
	tween.tween_property(get_node("../MenuButton"), "rect_position:x", final_val + 20, TWEEN_SPEED)
	return tween


# This function is a workaround for hiding and showing the menu smoothly
# Since the border width prevents the menu from sizing down to 0
# the border width needs to be set to 0
# but a border width is also nice to have some margin on the Button
func set_menu_button_border_width(value):
	var theme = get_node("/root/Main").get_theme()
	for stylebox_name in theme.get_stylebox_list("MyMenuButton"):
		var stylebox = theme.get_stylebox(stylebox_name, "MyMenuButton")
		stylebox.border_width_right = value
		stylebox.border_width_left = value


func set_min_size(value):
	for child in $SettingSeparator.get_children():
		child.rect_min_size.x = value
