extends Window

signal apply_text(text)
signal canceled

func show_popup():
	self.visible = true

func hide_popup():
	$MarginContainer/VBoxContainer/LineEdit.text = ""
	self.visible = false

func create_dialog(description, placeholder):
	$MarginContainer/VBoxContainer/VBoxContainer/AboveText.text = "[center]" + description + "[/center]"
	$MarginContainer/VBoxContainer/LineEdit.text = ""
	$MarginContainer/VBoxContainer/LineEdit.placeholder_text = placeholder
	show_popup()

func show_warning(warning):
	$MarginContainer/VBoxContainer/WarningText.text = warning

func hide_warning():
	show_warning("")

func _on_ConfirmButton_pressed():
	emit_signal("apply_text", $MarginContainer/VBoxContainer/LineEdit.text)


func _on_CancelButton_pressed():
	emit_signal("canceled")
	hide_popup()


func _on_LineEdit_text_entered(new_text):
	emit_signal("apply_text", new_text)


func _on_AboveText_meta_clicked(meta):
# warning-ignore:return_value_discarded
	OS.shell_open(meta)
