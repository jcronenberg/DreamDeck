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

# If button is currently being dragged
var _dragging = false


func _ready():
	# Required for dragging to work
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Anchors the button in the center, also needed for dragging (centers the preview)
	anchors_preset = 8
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -size.x / 2
	offset_top = -size.y / 2
	offset_right = size.x / 2
	offset_bottom = size.y / 2


## Called when [Macroboard] wants to save your button's configuration
func save() -> Dictionary:
	return {}


# Handles if drag was successful or not
func _notification(notif: int) -> void:
	if not _dragging:
		return
	# Drag failed
	if notif == NOTIFICATION_DRAG_END and not get_viewport().gui_is_drag_successful():
		visible = true
		_dragging = false
		# Drag successful
	elif notif == NOTIFICATION_DRAG_END:
		_dragging = false


func _get_drag_data(_at_position):
	if not GlobalSignals.get_edit_state():
		return

	var preview = Control.new()
	preview.add_child(self.duplicate())

	var data = {"ref": self, "type": "macroboard_button"}

	set_drag_preview(preview)
	visible = false
	_dragging = true

	return data
