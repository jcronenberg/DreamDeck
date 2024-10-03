extends CenterContainer


func _on_button_pressed():
	var panel_editor: PanelEditor = PanelEditor.new()
	panel_editor.show_new_panel()
	PopupManager.init_popup(panel_editor, panel_editor.save, func not_required(__) -> void: pass)
	GlobalSignals.enter_edit_mode()
