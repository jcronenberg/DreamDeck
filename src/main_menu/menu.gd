extends Panel

const TWEEN_SPEED := 0.5
const MAX_MENU_MARGIN := 400.0

# 1.0 when the menu slides out from the left edge, -1.0 when from the right.
var _dir: float = 1.0
var _edge_offset: float = 0.0
var _bg_style: StyleBoxFlat
var _tween: Tween
# Tracks the intended open/closed state independently of `visible`, since
# `visible` is only set to false once hide_menu()'s tween finishes, and a
# tween killed by an overlapping toggle never fires "finished", so `visible`
# alone can go stale under rapid toggling.
var _is_open: bool = false


func _ready() -> void:
	_bg_style = get_theme_stylebox("panel")

	GlobalSignals.menu_open_requested.connect(_open)
	GlobalSignals.sidebar_visibility_changed.connect(apply_config)
	ConfigLoader.config.config_changed.connect(apply_config)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_close_dialog"):
		_toggle()
		get_viewport().set_input_as_handled()


## Applies the global menu settings: colors, plus which side the menu slides
## out from. It follows the sidebar's edge, sliding out from the left unless
## the sidebar is on the right, and keeps clear of the sidebar when they
## share a side (unless the sidebar is hidden). Snaps to the new side even if
## currently open.
func apply_config() -> void:
	var data: Dictionary = ConfigLoader.get_config()
	_apply_colors(data)

	var pos: Sidebar.SidebarPosition = data["sidebar_position"]
	var thickness: float = data["sidebar_thickness"] if GlobalSignals.sidebar_visible else 0.0
	_dir = -1.0 if pos == Sidebar.SidebarPosition.RIGHT else 1.0
	var shares_side: bool = not Sidebar.is_horizontal_sidebar_position(pos)
	_edge_offset = thickness if shares_side else 0.0
	# Also keep clear of a horizontal sidebar by insetting the top/bottom edge.
	# These don't change while the menu slides, so they only need setting here.
	offset_top = thickness if pos == Sidebar.SidebarPosition.TOP else 0.0
	offset_bottom = -thickness if pos == Sidebar.SidebarPosition.BOTTOM else 0.0
	_apply_offsets(MAX_MENU_MARGIN if _is_open else 0.0)


## Applies the global "Menu background color"/"Menu font color" settings to
## this panel and to every button/label inside it.
func _apply_colors(data: Dictionary) -> void:
	_bg_style.bg_color = Color.hex(data["menu_bg_color"])

	var font_color: Color = Color.hex(data["menu_font_color"])
	for child in $SettingSeparator.get_children():
		child.add_theme_color_override("font_color", font_color)
		if child is Button:
			child.add_theme_color_override("font_hover_color", font_color)
			child.add_theme_color_override("font_pressed_color", font_color)
			child.add_theme_color_override("font_focus_color", font_color)
			child.add_theme_color_override("font_disabled_color", font_color)


func show_menu():
	if _tween:
		_tween.kill()
	_is_open = true
	_apply_offsets(0.0)
	visible = true
	_tween = tween_menu(MAX_MENU_MARGIN)
	clip_contents = false
	get_node("../ExitAreaButton").visible = true
	await _tween.finished
	set_menu_min_size(MAX_MENU_MARGIN)

	# TODO there probably is a better place for this or even a smarter way
	# For these buttons we need to set clip_text because otherwise
	# the fading out wouldn't work smoothly
	# Shouldn't be an issue because the names of these buttons should
	# not be changeable anyway
	for child in $SettingSeparator.get_children():
		child.clip_text = true


func hide_menu():
	if _tween:
		_tween.kill()
	_is_open = false
	get_node("../ExitAreaButton").visible = false
	clip_contents = true
	set_menu_min_size(0.0)
	_tween = tween_menu(0.0)
	await _tween.finished
	visible = false


func tween_menu(final_val):
	var tween := create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var far_edge: String = "offset_left" if _dir < 0 else "offset_right"
	tween.tween_property(self, far_edge, _far_offset(final_val), TWEEN_SPEED)
	return tween


func _toggle() -> void:
	if _is_open:
		hide_menu()
	else:
		show_menu()


func _open() -> void:
	if not _is_open:
		show_menu()


func set_menu_min_size(value):
	for child in $SettingSeparator.get_children():
		child.custom_minimum_size.x = value


# Anchors the panel to the correct edge and sets it to the given open width.
func _apply_offsets(width: float) -> void:
	var anchor: float = 0.0 if _dir > 0 else 1.0
	anchor_left = anchor
	anchor_right = anchor
	offset_left = minf(_dir * _edge_offset, _far_offset(width))
	offset_right = maxf(_dir * _edge_offset, _far_offset(width))


# The offset of the menu's far edge when open [param width] pixels: the near
# edge sits _edge_offset from the screen edge and the far edge is the open
# width further in, both signed away from the anchored screen edge.
func _far_offset(width: float) -> float:
	return _dir * (_edge_offset + width)
