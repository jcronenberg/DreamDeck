extends Panel

const TWEEN_SPEED := 0.5
const MAX_MENU_MARGIN := 400

@onready var setting_button := load("res://scenes/main_menu/submenu_button.tscn")


func show_menu():
	size.x = 0
	visible = true
	var tween = tween_menu(MAX_MENU_MARGIN)
	clip_contents = false
	get_node("../ExitAreaButton").visible = true
	await tween.finished
	set_menu_min_size(MAX_MENU_MARGIN)

	# TODO there probably is a better place for this or even a smarter way
	# For these buttons we need to set clip_text because otherwise
	# the fading out wouldn't work smoothly
	# Shouldn't be an issue because the names of these buttons should
	# not be changeable anyway
	for child in $SettingSeparator.get_children():
		child.clip_text = true


func hide_menu():
	GlobalSignals.emit_config_changed()
	for child in $SettingSeparator.get_children():
		if child.has_method("hide_submenu"):
			child.hide_submenu()
	clip_contents = true
	set_menu_min_size(0.0)
	size.x = MAX_MENU_MARGIN
	var tween = tween_menu(0.0)
	await tween.finished
	get_node("../ExitAreaButton").visible = false
	visible = false


func tween_menu(final_val):
	var tween := create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.set_parallel()
	tween.tween_property(self, "size:x", final_val, TWEEN_SPEED)
	tween.tween_property(get_node("../MenuButton"), "position:x", final_val + 20, TWEEN_SPEED)
	return tween


func set_menu_min_size(value):
	for child in $SettingSeparator.get_children():
		child.custom_minimum_size.x = value
