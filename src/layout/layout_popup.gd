class_name LayoutPopup
extends Window


func show_config(editor: Config.ConfigEditor, panel_name: String):
	show()
	title = "Edit settings of " + panel_name
	%PanelEditor.show_panel_config(editor)


func new_panel():
	show()
	title = "Add new panel"
	%PanelEditor.show_new_panel()


func _on_confirm_button_pressed():
	if %PanelEditor.save():
		self.visible = false


func _on_cancel_button_pressed():
	self.visible = false
