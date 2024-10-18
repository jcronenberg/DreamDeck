extends Node

signal entered_edit_mode
signal exited_edit_mode
signal activated_plugins_changed


var edit_state: bool = false


func toggle_edit_mode():
	if edit_state:
		exit_edit_mode()
	else:
		enter_edit_mode()


func enter_edit_mode():
	edit_state = true
	entered_edit_mode.emit()


func exit_edit_mode():
	edit_state = false
	exited_edit_mode.emit()


func get_edit_state() -> bool:
	return edit_state


# The purpose for this function is mainly when importing a config backup.
# It basically completely resets everything and then switches to a new main scene.
func _perform_complete_reinit() -> void:
	PluginCoordinator._reinit()
	ConfigLoader.load_config()
	var main_scene: PackedScene = load("res://src/main/main.tscn")
	get_tree().change_scene_to_packed(main_scene)
