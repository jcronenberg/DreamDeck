class_name MinimizeController
extends PluginControllerBase
## Controller backing the "Minimize" action.
##
## Minimizes the main window and spawns a small floating [MinimizeOverlayWindow]
## with a button that restores it again.

enum Corner { TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT }

const PLUGIN_NAME := "Minimize"
const QUICK_BAR_SCENE: PackedScene = preload(
	"res://plugins/macroboard/src/macroboard/macroboard.tscn"
)
const QUICK_BAR_ID := "minimize_quick_bar"

var _overlay_window: MinimizeOverlayWindow = null
# Window mode to restore to, captured right before minimizing.
var _previous_window_mode: int = Window.MODE_WINDOWED

var _corner: int = Corner.BOTTOM_RIGHT
var _margin: int = 20
var _ungrab_touch_on_minimize: bool = false
var _quick_bar_amount: int = 3

var _quick_bar: Macroboard = null

# Screen the overlay was placed on, captured right before minimizing (while the
# main window's geometry is still reliable) and reused for any later resize
# (e.g. expanding the quick action bar), since the main window's geometry can
# no longer be trusted once it's minimized.
var _overlay_screen: int = 0

# Setting Window.mode = MODE_MINIMIZED isn't necessarily synchronous with some
# window managers, so [method _process] must wait for confirmation that the
# window actually reached MODE_MINIMIZED before it starts treating "mode is no
# longer MODE_MINIMIZED" as a sign the user restored it externally. Without
# this, the still-in-flight minimize request would immediately look like a
# restore and tear the overlay down before it was ever seen.
var _minimize_confirmed: bool = false


func _init() -> void:
	plugin_name = PLUGIN_NAME
	config.add_dict("Button position", "corner", Corner.BOTTOM_RIGHT, Corner)
	config.add_int(
		"Button margin",
		"margin",
		20,
		"Distance in pixels from the screen edges to the restore button"
	)
	config.add_bool(
		"Ungrab touch device while minimized",
		"ungrab_touch_on_minimize",
		false,
		(
			"By default the touch device (if the Touch plugin is active) stays grabbed while "
			+ "minimized. Enable this to release it until the app is restored."
		)
	)
	config.add_int(
		"Quick action bar buttons",
		"quick_bar_amount",
		3,
		(
			"Amount of buttons in the quick action bar shown next to the restore button "
			+ "(requires the Macroboard plugin to be active)"
		)
	)


func handle_config() -> void:
	var data: Dictionary = config.get_as_dict()
	_corner = data["corner"]
	_margin = data["margin"]
	_ungrab_touch_on_minimize = data["ungrab_touch_on_minimize"]
	_quick_bar_amount = data["quick_bar_amount"]

	if _quick_bar:
		_apply_quick_bar_config(_quick_bar)


## Action entrypoint: minimizes the main window and spawns the restore button.
## Actions can be invoked from a background thread (e.g. macro buttons run on a
## worker thread), but Window/node-tree access requires the main thread.
func minimize_app(_blocking: bool) -> void:
	_minimize.call_deferred()


func _minimize() -> void:
	# Defensive: if the overlay reference is stale (freed by something other than
	# _finish_restore, e.g. the window manager closing it), don't let it wedge us.
	if _overlay_window and not is_instance_valid(_overlay_window):
		_overlay_window = null

	if _overlay_window:
		return

	# Computed before minimizing, while the window's current screen is still reliable.
	_overlay_screen = _get_window_screen()

	_previous_window_mode = get_window().mode
	_minimize_confirmed = false
	get_window().mode = Window.MODE_MINIMIZED

	if _ungrab_touch_on_minimize:
		_set_touch_grabbed(false)

	_overlay_window = MinimizeOverlayWindow.new(self)
	_overlay_window.restore_requested.connect(_on_restore_requested)
	add_child(_overlay_window)
	_overlay_window.show()

	var touch_controller: TouchController = _get_touch_controller()
	if touch_controller:
		touch_controller.register_window(_overlay_window)

	set_process(true)


# Some window managers apply MODE_MINIMIZED asynchronously, so the main window
# can also be un-minimized by something other than our overlay button (OS
# taskbar, Alt-Tab, window manager shortcut, ...). We treat "window mode is no
# longer MODE_MINIMIZED after having actually reached it" as the single source
# of truth for an external restore and poll for it here. The "after having
# actually reached it" part matters: right after requesting the minimize, mode
# may still briefly read as the old (non-minimized) value, which must not be
# mistaken for a restore.
func _process(_delta: float) -> void:
	if not _overlay_window:
		return

	if not is_instance_valid(_overlay_window):
		_overlay_window = null
		set_process(false)
		return

	var current_mode: int = get_window().mode
	if not _minimize_confirmed:
		if current_mode == Window.MODE_MINIMIZED:
			_minimize_confirmed = true
		return

	if current_mode != Window.MODE_MINIMIZED:
		_finish_restore()


# Called when the overlay button is pressed (or the overlay window is closed).
# Performs the restore directly instead of relying on [method _process] to
# notice, since that would race the window manager's (possibly async) handling
# of the mode change.
func _on_restore_requested() -> void:
	get_window().mode = _previous_window_mode
	get_window().grab_focus()
	_finish_restore()


func _finish_restore() -> void:
	set_process(false)
	_minimize_confirmed = false

	if _ungrab_touch_on_minimize:
		_set_touch_grabbed(true)

	detach_quick_bar()

	if is_instance_valid(_overlay_window):
		var touch_controller: TouchController = _get_touch_controller()
		if touch_controller:
			touch_controller.unregister_window(_overlay_window)
		_overlay_window.queue_free()
	_overlay_window = null


func get_corner() -> int:
	return _corner


## Whether the quick action bar can be shown, i.e. the Macroboard plugin is active.
func has_quick_bar() -> bool:
	return PluginCoordinator.get_plugin_loader("Macroboard") != null


func get_quick_bar_amount() -> int:
	return _quick_bar_amount


## Returns the shared quick action bar instance, creating it on first use.
## Returns null if [method has_quick_bar] is false.
func get_quick_bar() -> Macroboard:
	if not has_quick_bar():
		return null

	if not _quick_bar:
		_quick_bar = QUICK_BAR_SCENE.instantiate()
		_quick_bar.init(QUICK_BAR_ID)
		_apply_quick_bar_config(_quick_bar)

	return _quick_bar


## Moves the quick action bar under [param target], creating it on first use.
## Returns null if [method has_quick_bar] is false.
func attach_quick_bar(target: Control) -> Macroboard:
	var quick_bar: Macroboard = get_quick_bar()
	if not quick_bar:
		return null

	if quick_bar.get_parent() == target:
		return quick_bar
	if quick_bar.get_parent():
		quick_bar.reparent(target)
	else:
		target.add_child(quick_bar)

	return quick_bar


## Removes the quick action bar from its current parent (if any) without
## freeing it, so it can be reused the next time it's attached.
func detach_quick_bar() -> void:
	if _quick_bar and _quick_bar.get_parent():
		_quick_bar.get_parent().remove_child(_quick_bar)


## Live-previews [param amount] buttons on the shared quick bar without persisting
## it to [member _quick_bar_amount], so the settings popup's embedded editor can
## reflect in-progress edits immediately. Reverted (or committed) by
## [method sync_quick_bar_config] once the setting is actually applied or discarded.
func preview_quick_bar_amount(amount: int) -> void:
	if _quick_bar:
		_quick_bar.config.apply_dict({"columns": amount, "rows": 1, "square_buttons": false})


## Resyncs the shared quick bar to the currently persisted [member _quick_bar_amount],
## discarding any unsaved preview from [method preview_quick_bar_amount].
func sync_quick_bar_config() -> void:
	if _quick_bar:
		_apply_quick_bar_config(_quick_bar)


func _apply_quick_bar_config(quick_bar: Macroboard) -> void:
	quick_bar.config.apply_dict({"columns": _quick_bar_amount, "rows": 1, "square_buttons": false})


## Computes the screen position an overlay of [param overlay_size] should be placed
## at, anchored to [member _corner] on [member _overlay_screen].
func get_overlay_position(overlay_size: Vector2i) -> Vector2i:
	var screen_position: Vector2i = DisplayServer.screen_get_position(_overlay_screen)
	var screen_size: Vector2i = DisplayServer.screen_get_size(_overlay_screen)

	var offset: Vector2i
	match _corner:
		Corner.TOP_LEFT:
			offset = Vector2i(_margin, _margin)
		Corner.TOP_RIGHT:
			offset = Vector2i(screen_size.x - overlay_size.x - _margin, _margin)
		Corner.BOTTOM_LEFT:
			offset = Vector2i(_margin, screen_size.y - overlay_size.y - _margin)
		Corner.BOTTOM_RIGHT:
			offset = Vector2i(
				screen_size.x - overlay_size.x - _margin, screen_size.y - overlay_size.y - _margin
			)

	return screen_position + offset


func _set_touch_grabbed(grabbed: bool) -> void:
	var touch_controller: TouchController = _get_touch_controller()
	if not touch_controller:
		return

	if grabbed:
		touch_controller.grab_device()
	else:
		touch_controller.ungrab_device()


func _get_touch_controller() -> TouchController:
	var touch_loader: PluginLoaderBase = PluginCoordinator.get_plugin_loader("Touch")
	if not touch_loader:
		return null
	return touch_loader.get_controller("TouchController") as TouchController


# Window.current_screen can reflect the OS's active/focused output rather than
# the screen the main window actually sits on (observed on multi-monitor setups
# where focus/cursor is elsewhere), so the screen is instead derived from the
# window's own geometry.
func _get_window_screen() -> int:
	var window: Window = get_window()
	var window_center: Vector2i = window.position + window.size / 2

	for screen in DisplayServer.get_screen_count():
		var screen_rect: Rect2i = Rect2i(
			DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen)
		)
		if screen_rect.has_point(window_center):
			return screen

	return window.current_screen
