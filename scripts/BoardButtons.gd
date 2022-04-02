extends Control


func _on_MacroButton_button_up():
	print("restarting grab_thread")
	get_node("/root/GrabTouchscreen").call("restart_grab_thread")


func _on_MacroButton2_button_down():
	print("killing grab_thread")
	get_node("/root/GrabTouchscreen").call("kill_grab_thread")
