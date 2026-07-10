class_name MinimizeOverlayWindow
extends Window
## A small always-on-top window holding a single button to restore the main window.
##
## Built entirely in code (no scene), mirroring [PopupManager]'s SimpleWindow.

signal restore_requested

const ICON: Texture2D = preload("res://resources/icons/dreamdeck.png")

var _button: TextureButton = TextureButton.new()
var _target_position: Vector2i = Vector2i.ZERO


func _init(overlay_size: Vector2i, overlay_position: Vector2i) -> void:
	# A freshly created Window defaults to visible=true, but force_native can't
	# be changed while "displayed" (even before entering the tree). Hidden here,
	# shown explicitly once fully configured and added to the tree.
	visible = false
	size = overlay_size
	position = overlay_position
	_target_position = overlay_position
	borderless = true
	always_on_top = true
	unresizable = true
	# Forces a real native window regardless of the project's
	# display/window/subwindows/embed_subwindows setting, which otherwise draws
	# subwindows into the main viewport and would make this invisible while the
	# main window is minimized.
	force_native = true

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.12549, 0.121569, 0.14902, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_button.texture_normal = ICON
	_button.ignore_texture_size = true
	_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	_button.pressed.connect(func() -> void: restore_requested.emit())
	add_child(_button)


func _ready() -> void:
	close_requested.connect(func() -> void: restore_requested.emit())
	# Some window managers ignore the requested position on the window's
	# initial map, instead placing it on the currently focused
	# monitor/workspace, but do honor an explicit move once it's already
	# mapped. Re-apply the position a couple of frames after showing to win
	# back control from that placement policy.
	await get_tree().process_frame
	await get_tree().process_frame
	position = _target_position
