extends Button

onready var global_signals = get_node("/root/GlobalSignals")

func _on_EditModeButton_pressed():
	if global_signals.get_edit_state():
		global_signals.exit_edit_mode()
	else:
		global_signals.enter_edit_mode()
