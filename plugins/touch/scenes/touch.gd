class_name Touch
extends PluginSceneBase

@onready var _controller: TouchController = PluginCoordinator.get_plugin_loader("touch").get_controller()


func _on_reconnect_button_pressed():
	_controller.reconnect_device()


func _on_grab_check_button_toggled(toggled_on):
	if toggled_on:
		_controller.grab_device()
	else:
		_controller.ungrab_device()
