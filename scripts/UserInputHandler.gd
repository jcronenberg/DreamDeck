# This script handles user input
# The caller can create a dialog and should then connect to the signals provided by this script
# The signals get called when something happens in the dialog
# It is also the job of the caller to check for the right input, set warnings accordingly
# or close the dialog if it has it's desired input
# Example:
#   user_input_handler.create_dialog("Description", "Placeholder")
#   user_input_handler.connect("apply_text", self, "_text")
#   user_input_handler.connect("cancelled", self, "_cancelled")
#   do something when signals called
#   if not satisfied with the user's input you can show a warning
#   user_input_handler.show_warning("That was so wrong michael!")
#   if satisfied with the user's input disconnect from the signals and hide the popup
#   Important! In this order as it could be another node trying to open a popup also
#   user_input_handler.disconnect("apply_text", self, "_text")
#   user_input_handler.disconnect("cancelled", self, "_cancelled")
#   user_input_handler.hide()
extends Node

signal apply_text(text)
signal cancelled

var popup
var popup_opened: bool = false

func _ready():
	popup = get_node("/root/Main/UserInputPopup")
	popup.connect("apply_text", self, "_on_apply_text")
	popup.connect("cancelled", self, "_on_cancelled")

func create_dialog(description, placeholder) -> bool:
	if popup_opened:
		return false
	popup.create_dialog(description, placeholder)
	popup_opened = true
	return true

func hide():
	popup.hide()
	hide_warning()
	popup_opened = false

func show_warning(warning):
	popup.show_warning(warning)

func hide_warning():
	show_warning("")

func _on_apply_text(text):
	emit_signal("apply_text", text)

func _on_cancelled():
	emit_signal("cancelled")
