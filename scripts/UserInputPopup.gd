extends WindowDialog

signal apply_text(text)
signal cancelled

func show():
	self.visible = true

func hide():
	self.visible = false

func create_dialog(description, placeholder):
	$MarginContainer/VBoxContainer/AboveText.text = description
	$MarginContainer/VBoxContainer/LineEdit.placeholder_text = placeholder
	show()

func show_warning(warning):
	$MarginContainer/VBoxContainer/WarningText.text = warning

func hide_warning():
	show_warning("")

func _on_ConfirmButton_pressed():
	emit_signal("apply_text", $MarginContainer/VBoxContainer/LineEdit.text)


func _on_CancelButton_pressed():
	emit_signal("cancelled")
	hide()


func _on_LineEdit_text_entered(new_text):
	emit_signal("apply_text", new_text)
