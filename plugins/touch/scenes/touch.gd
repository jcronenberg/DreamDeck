class_name Touch
extends PluginSceneBase

@onready
var _controller: TouchController = PluginCoordinator.get_plugin_loader("Touch").get_controller(
	"TouchController"
)


func _ready() -> void:
	super()
	_controller.grab_state_changed.connect(_on_grab_state_changed)
	_on_grab_state_changed(_controller.is_device_grabbed())


func _on_reconnect_button_pressed():
	_controller.reconnect_device()


func _on_grab_check_button_toggled(toggled_on):
	if toggled_on:
		_controller.grab_device()
	else:
		_controller.ungrab_device()


# Reflects grab-state changes triggered elsewhere (e.g. the toggle action) in
# the checkbox, without re-triggering _on_grab_check_button_toggled.
func _on_grab_state_changed(grabbed: bool) -> void:
	%GrabCheckButton.set_pressed_no_signal(grabbed)
