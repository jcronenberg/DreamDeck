extends Node

signal entered_edit_mode
signal exited_edit_mode
signal entered_resize_mode
signal exited_resize_mode
signal activated_plugins_changed
signal menu_open_requested
signal sidebar_visibility_changed

var edit_state: bool = false
var resize_state: bool = false
var sidebar_visible: bool = true


func toggle_edit_mode():
	if edit_state:
		exit_edit_mode()
	else:
		enter_edit_mode()


func enter_edit_mode():
	if resize_state:
		exit_resize_mode()
	edit_state = true
	entered_edit_mode.emit()


func exit_edit_mode():
	edit_state = false
	exited_edit_mode.emit()


func get_edit_state() -> bool:
	return edit_state


func toggle_resize_mode():
	if resize_state:
		exit_resize_mode()
	else:
		enter_resize_mode()


func enter_resize_mode():
	if edit_state:
		exit_edit_mode()
	resize_state = true
	entered_resize_mode.emit()


func exit_resize_mode():
	resize_state = false
	exited_resize_mode.emit()


func get_resize_state() -> bool:
	return resize_state


func toggle_sidebar():
	sidebar_visible = not sidebar_visible
	sidebar_visibility_changed.emit()


# The purpose for this function is mainly when importing a config backup.
# It basically completely resets everything and then switches to a new main scene.
func _perform_complete_reinit() -> void:
	PluginCoordinator._reinit()
	ConfigLoader.load_config()
	var main_scene: PackedScene = load("res://src/main/main.tscn")
	get_tree().change_scene_to_packed(main_scene)
