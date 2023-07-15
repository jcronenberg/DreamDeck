extends Window

var cur_row: int
var cur_pos: int
var button_to_edit: Node


# Function to be called when a button is supposed to be created/edited
# row: row in which the button is supposed to be/ currently is
# pos: position in the row in which the button currently is
# button: if a new button is supposed to be created this has to be null
#         otherwise if an existing button is supposed to be edited
#         this should be the instance of said button
func show_popup(row, pos, button):
	cur_row = row
	cur_pos = pos
	button_to_edit = button
	$"%Header".text = "Editing Button on Row: " + str(cur_row + 1) + " Pos: " + str(cur_pos + 1) + \
		". Hover for a tooltip"
	$MarginContainer/Rows/PositionSplit/LineEdit.text = str(cur_pos + 1)
	if button.has_method("save"):
		fill_from_button_dict(button.save())
		$"%DeleteButton".visible = true
	else:
		$"%DeleteButton".visible = false
	visible = true


func _on_ConfirmButton_pressed():
	visible = false
	# TODO error handling
	cur_pos = int($MarginContainer/Rows/PositionSplit/LineEdit.text) - 1
	get_parent().add_or_edit_button(cur_row, cur_pos, create_button_dict(), button_to_edit)
	reset_prompt()


func _on_CancelButton_pressed():
	reset_prompt()
	visible = false


func _on_DeleteButton_pressed():
	reset_prompt()
	if button_to_edit:
		# Can't queue_free here as we need it gone to properly delete the row
		# because remove_add_buttons only delete's the row when no button is present
		get_parent().delete_button(button_to_edit)

	visible = false


# Creates and returns a dictionary from all input fields
func create_button_dict() -> Dictionary:
	var button_dict = {}
	button_dict["app"] = $MarginContainer/Rows/AppSplit/LineEdit.text
	button_dict["arguments"] = text_to_args($MarginContainer/Rows/ArgumentsSplit/LineEdit.text)
	button_dict["app_name"] = $MarginContainer/Rows/AppNameSplit/LineEdit.text
	button_dict["icon_path"] = $MarginContainer/Rows/IconPathSplit/LineEdit.text
	button_dict["show_app_name"] = $MarginContainer/Rows/ShowAppNameSplit/CheckBox.pressed

	return button_dict


# Takes a dict with a button's keys and fills all LineEdits with the values
func fill_from_button_dict(button_dict):
	$MarginContainer/Rows/AppSplit/LineEdit.text = button_dict["app"]
	$MarginContainer/Rows/ArgumentsSplit/LineEdit.text = args_to_text(button_dict["arguments"])
	$MarginContainer/Rows/AppNameSplit/LineEdit.text = button_dict["app_name"]
	$MarginContainer/Rows/IconPathSplit/LineEdit.text = button_dict["icon_path"]
	$MarginContainer/Rows/ShowAppNameSplit/CheckBox.button_pressed = button_dict["show_app_name"]


# Resets all LineEdit's to default state
func reset_prompt():
	$MarginContainer/Rows/AppSplit/LineEdit.text = ""
	$MarginContainer/Rows/ArgumentsSplit/LineEdit.text = ""
	$MarginContainer/Rows/AppNameSplit/LineEdit.text = ""
	$MarginContainer/Rows/IconPathSplit/LineEdit.text = ""
	$MarginContainer/Rows/ShowAppNameSplit/CheckBox.button_pressed = false


func args_to_text(args) -> String:
	var ret = ""
	for arg in args:
		ret += arg + " "

	ret.erase(ret.length() - 1, 1)
	return ret


func text_to_args(args) -> Array:
	return args.split(" ")

