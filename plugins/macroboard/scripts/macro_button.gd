class_name MacroButton
extends Button
## Base button for [Macroboard].
##
## Overwrite the [method save] method and define how your button behaves
## when the [signal Button.pressed] signal is executed.[br]
## If you need [signal Button.button_up] or [signal Button.button_down]
## take care to not break the required functionality of [Macroboard].[br]
## Ensure also everything saved can also be set by the same name.
## So if you return a dict like:
## [codeblock]
## {"config1": true, "config2": 2}
## [/codeblock]
## Your button should have
## [codeblock]
## var config1: bool
## var config2: int
## [/codeblock]

# Unique identifier for your button's type. Needs to be the same as the name of
# your directory in [code]"res://plugins/macroboard/button_types/"[/code].
#var button_type: String = ""

# Variables that are used for dragging in edit mode
const _lifted_cooldown := 0.4 # Time in seconds before button gets lifted
var _lifted = false
var _lift_timer := 0.0

# Global nodes
@onready var _global_signals = get_node("/root/GlobalSignals")


func _ready():
	set_process_input(false)
	set_process(false)
	connect("button_down", Callable(self, "_on_button_down"))
	connect("button_up", Callable(self, "_on_button_up"))


# We need to keep track of global input events when the button is being dragged,
# because we reparent and that has the effect of losing the pressed down state.
# To work around that, we watching global input for a button up event.
# When that gets triggered we can trigger the _on_button_up function ourselves.
func _input(event):
	if not _lifted:
		set_process_input(false)
	if event is InputEventMouseButton:
		if event.pressed == false:
			_on_button_up()
			set_process_input(false)


func _process(delta):
	# Lifted countdown
	if _lift_timer + delta > _lifted_cooldown:
		# See _input function for explanation
		set_process_input(true)
		# Reparent so we can replace the button with an empty one
		# and also to keep getting gui_input events when moving to another row
		reparent(get_node("../../.."))
		_lifted = true
		set_process(false)
	else:
		_lift_timer += delta


## Called when [Macroboard] wants to save your button's configuration
func save() -> Dictionary:
	return {}


# TODO right now when the mouse is moved too fast, the cursor "loses" the button and we don't receive events
# until the cursor enters the button area again. This can be circumvented by using global input
# but the problem with global input is that position is also global and to macroboard relative
# so we would need to get macroboard position and deduct that from input position
func _on_gui_input(event):
	# When lifted, update position to cursor position
	if _lifted and (event is InputEventMouseMotion or event is InputEventMouseButton):
		# Mouse is supposed to be at the center, so we deduct half of size
		position += event.position - size / 2
		# handle_lifted_button expects cursor position, so we need to add half of size again
		# note that we can't use event.position, because it is relative to button and not macroboard
		# which handle_lifted_button expects
		get_parent()._handle_lifted_button(position + size / 2, self)


# Reset all dragging variables/states
func _on_button_up():
	if _lifted:
		_lifted = false
		get_parent()._place_button(self)
	_lift_timer = 0.0
	set_process(false)
	set_process_input(true)


# Function that when in edit mode activates the lift_timer
# (or in this case the process function)
func _on_button_down():
	if not _global_signals.get_edit_state():
		return
	if not _lifted:
		set_process(true)
