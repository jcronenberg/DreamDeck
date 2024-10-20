extends CenterContainer


func _on_button_pressed():
	var new_panel_editor: NewPanelEditor = NewPanelEditor.new()
	PopupManager.init_popup([new_panel_editor], new_panel_editor.save)
	GlobalSignals.enter_edit_mode()
