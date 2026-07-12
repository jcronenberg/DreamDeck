class_name MinimizeOverlayWindow
extends Window
## A small always-on-top window holding a button to restore the main window,
## plus (if the Macroboard plugin is active) a toggle that expands a quick
## action bar to the side.
##
## Built entirely in code (no scene), mirroring [PopupManager]'s SimpleWindow.

signal restore_requested

const ICON: Texture2D = preload("res://resources/icons/dreamdeck.png")
const BUTTON_SIZE: Vector2i = Vector2i(64, 64)

var _controller: MinimizeController
var _restore_button: TextureButton = TextureButton.new()
# Only created when the controller reports a quick bar is available (also
# serving as the "quick bar exists" check), so a parentless Control isn't
# leaked on every minimize when it's not.
var _toggle_button: Button = null
# A MarginContainer (rather than a plain Control) so it actively forces the
# embedded quick bar to its own size on every layout pass; a plain Control would
# let the bar keep whatever size it had in its previous parent (e.g. the much
# wider settings popup), since a reparent alone never triggers a resize.
var _bar_container: MarginContainer = null
var _hbox: HBoxContainer = HBoxContainer.new()
var _expanded: bool = false


func _init(controller: MinimizeController) -> void:
	# A freshly created Window defaults to visible=true, but force_native can't
	# be changed while "displayed" (even before entering the tree). Hidden here,
	# shown explicitly once fully configured and added to the tree.
	visible = false
	_controller = controller
	borderless = true
	always_on_top = true
	unresizable = true
	# Forces a real native window regardless of the project's
	# display/window/subwindows/embed_subwindows setting, which otherwise draws
	# subwindows into the main viewport and would make this invisible while the
	# main window is minimized.
	force_native = true

	# Mirrors the main window's background transparency (see [ConfigLoader]) now
	# that there's no opaque ColorRect behind the buttons.
	transparent = true
	set_transparent_background(ConfigLoader.get_config()["transparent_bg"])

	_hbox.add_theme_constant_override("separation", 0)
	_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_hbox)

	_restore_button.texture_normal = ICON
	_restore_button.ignore_texture_size = true
	_restore_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_restore_button.custom_minimum_size = Vector2(BUTTON_SIZE)
	_restore_button.pressed.connect(func() -> void: restore_requested.emit())

	if _controller.has_quick_bar():
		_toggle_button = Button.new()
		_toggle_button.custom_minimum_size = Vector2(BUTTON_SIZE)
		_toggle_button.pressed.connect(_on_toggle_pressed)

		_bar_container = MarginContainer.new()
		_bar_container.clip_contents = true

	_layout_children()
	_resize_to_current_state()


func _ready() -> void:
	close_requested.connect(func() -> void: restore_requested.emit())
	# Some window managers ignore the requested position on the window's initial
	# map but honor an explicit move once it's mapped, so re-apply it a couple of
	# frames after showing.
	await get_tree().process_frame
	await get_tree().process_frame
	_resize_to_current_state()


# Orders the restore button, toggle button and action bar so the bar always
# grows away from the screen edge the overlay is pinned to.
func _layout_children() -> void:
	for child in _hbox.get_children():
		_hbox.remove_child(child)

	var pinned_left: bool = (
		_controller.get_corner()
		in [MinimizeController.Corner.TOP_LEFT, MinimizeController.Corner.BOTTOM_LEFT]
	)

	var children: Array[Control] = [_restore_button]
	if _toggle_button:
		children.append(_toggle_button)
		children.append(_bar_container)
	if not pinned_left:
		children.reverse()

	for child in children:
		_hbox.add_child(child)

	_update_toggle_text(pinned_left)
	_apply_bar_gap(pinned_left)


# Gives the bar a gap from the toggle button, matching the spacing between
# buttons within the macroboard itself, on whichever side the toggle button
# is on (the bar's other side stays flush with the edge of the window).
func _apply_bar_gap(pinned_left: bool) -> void:
	if not _bar_container:
		return

	# Collapsed, the bar must contribute zero size on its own -- MarginContainer
	# adds its margins on top of the (zero) child minimum size regardless of
	# custom_minimum_size, so a stray margin here would show up as dead space
	# next to the toggle button and push the restore button off-window.
	var gap: int = Macroboard.BUTTON_GAP if _expanded else 0
	_bar_container.add_theme_constant_override("margin_left", gap if pinned_left else 0)
	_bar_container.add_theme_constant_override("margin_right", 0 if pinned_left else gap)


func _update_toggle_text(pinned_left: bool) -> void:
	if not _toggle_button:
		return

	var points_away_from_restore: bool = pinned_left != _expanded
	_toggle_button.text = "›" if points_away_from_restore else "‹"


func _on_toggle_pressed() -> void:
	_expanded = not _expanded

	if _expanded:
		_controller.attach_quick_bar(_bar_container)
	else:
		_controller.detach_quick_bar()

	refresh_layout()


## Re-derives child order and window size/position from the controller's
## current corner. Called after [method MinimizeController.move_to_corner]
## moves the overlay to a different corner of the screen.
func refresh_layout() -> void:
	_layout_children()
	_resize_to_current_state()


func _get_bar_width() -> int:
	if not _expanded or not _bar_container:
		return 0
	return _controller.get_quick_bar_amount() * BUTTON_SIZE.x + Macroboard.BUTTON_GAP


func _current_size() -> Vector2i:
	var button_count: int = 2 if _toggle_button else 1
	return Vector2i(BUTTON_SIZE.x * button_count + _get_bar_width(), BUTTON_SIZE.y)


func _resize_to_current_state() -> void:
	if _bar_container:
		_bar_container.custom_minimum_size = Vector2(_get_bar_width(), BUTTON_SIZE.y)

	var new_size: Vector2i = _current_size()
	size = new_size
	position = _controller.get_overlay_position(new_size)
