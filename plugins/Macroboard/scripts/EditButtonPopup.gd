extends PopupPanel
## Popup for creating or editing buttons in [Macroboard].
class_name EditButtonPopup

## [b]Instance[/b] of the button that is supposed to be edited.
var button_to_edit: Node


## Shows the popup to create or edit a button.[br]
## [param button]: [b]Instance[/b] of the button to add/edit
func show_popup(button):
	reset_prompt()
	button_to_edit = button
	if button.has_method("save"):
		title = "Edit Button. (Hover for a tooltip)"
		fill_from_button_dict(button.save())
		$"%DeleteButton".visible = true
	else:
		title = "Create Button. (Hover for a tooltip)"
		$"%DeleteButton".visible = false
	visible = true


func _on_ConfirmButton_pressed():
	visible = false
	get_parent().add_or_edit_button(button_to_edit, create_button_dict())
	reset_prompt()


func _on_CancelButton_pressed():
	reset_prompt()
	visible = false


func _on_DeleteButton_pressed():
	reset_prompt()
	if button_to_edit:
		get_parent().delete_button(button_to_edit)

	visible = false


## Creates and returns a dictionary from all input fields.
func create_button_dict() -> Dictionary:
	var button_dict = {}
	button_dict["app"] = $MarginContainer/Rows/AppSplit/LineEdit.text
	button_dict["arguments"] = text_to_args($MarginContainer/Rows/ArgumentsSplit/LineEdit.text)
	button_dict["app_name"] = $MarginContainer/Rows/AppNameSplit/LineEdit.text
	button_dict["icon_path"] = $MarginContainer/Rows/IconPathSplit/LineEdit.text
	button_dict["show_app_name"] = $MarginContainer/Rows/ShowAppNameSplit/CheckBox.pressed

	return button_dict


## Takes a [Dictionary] with a button's keys and fills all LineEdits with the values.
func fill_from_button_dict(button_dict: Dictionary):
	$MarginContainer/Rows/AppSplit/LineEdit.text = button_dict["app"]
	$MarginContainer/Rows/ArgumentsSplit/LineEdit.text = args_to_text(button_dict["arguments"])
	$MarginContainer/Rows/AppNameSplit/LineEdit.text = button_dict["app_name"]
	$MarginContainer/Rows/IconPathSplit/LineEdit.text = button_dict["icon_path"]
	$MarginContainer/Rows/ShowAppNameSplit/CheckBox.button_pressed = button_dict["show_app_name"]


## Resets all inputs to default state.
func reset_prompt():
	$MarginContainer/Rows/AppSplit/LineEdit.text = ""
	$MarginContainer/Rows/ArgumentsSplit/LineEdit.text = ""
	$MarginContainer/Rows/AppNameSplit/LineEdit.text = ""
	$MarginContainer/Rows/IconPathSplit/LineEdit.text = ""
	$MarginContainer/Rows/ShowAppNameSplit/CheckBox.button_pressed = false


## Creates a single [String] from an [Array] of [String]s.
func args_to_text(args) -> String:
	var ret = ""
	for arg in args:
		ret += arg + " "

	ret.erase(ret.length() - 1, 1)
	return ret


## Creates an [Array] of [String]s from a single [String].
func text_to_args(args) -> Array:
	return args.split(" ")
