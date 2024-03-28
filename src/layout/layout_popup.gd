class_name LayoutPopup
extends Window
## TODO


func show_config(editor: Config.ConfigEditor):
	show()
	%PanelEditor.show_panel_config(editor)


func new_panel():
	show()
	%PanelEditor.show_new_panel()


func _on_confirm_button_pressed():
	if %PanelEditor.save():
		self.visible = false


func _on_cancel_button_pressed():
	self.visible = false
