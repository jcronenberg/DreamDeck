class_name Sidebar
extends Panel

enum SidebarPosition { LEFT, RIGHT, TOP, BOTTOM }

const MACROBOARD_SCENE: PackedScene = preload(
	"res://plugins/macroboard/src/macroboard/macroboard.tscn"
)

# Fixed conf id so the sidebar's board keeps its own config/layout,
# separate from any Macroboard instances placed as regular panels.
const CONF_ID := "sidebar_macroboard"

const DEFAULT_COLUMNS := 1
const DEFAULT_ROWS := 6

var _macroboard: Macroboard
var _bg_style: StyleBoxFlat
var _last_horizontal: bool = false


## Returns true if [param pos] runs along the top or bottom edge (a horizontal
## bar) rather than the left or right edge (a vertical rail).
static func is_horizontal_sidebar_position(pos: SidebarPosition) -> bool:
	return pos == SidebarPosition.TOP or pos == SidebarPosition.BOTTOM


func _ready() -> void:
	_bg_style = get_theme_stylebox("panel")

	_macroboard = MACROBOARD_SCENE.instantiate()
	_macroboard.config.get_object("columns").set_value(DEFAULT_COLUMNS)
	_macroboard.config.get_object("rows").set_value(DEFAULT_ROWS)
	_macroboard.init(CONF_ID)
	%MacroboardContainer.add_child(_macroboard)

	GlobalSignals.entered_edit_mode.connect(_on_entered_edit_mode)
	GlobalSignals.exited_edit_mode.connect(_on_exited_edit_mode)
	%SettingsButton.visible = GlobalSignals.get_edit_state()

	GlobalSignals.sidebar_visibility_changed.connect(_on_sidebar_visibility_changed)
	visible = GlobalSignals.sidebar_visible

	# The board's persisted columns/rows already match whatever orientation was
	# last saved, so seed this before the first _apply_config() to avoid
	# swapping it right back on the very first application.
	_last_horizontal = is_horizontal_sidebar_position(ConfigLoader.get_config()["sidebar_position"])

	ConfigLoader.config.config_changed.connect(_apply_config)
	_apply_config()


func _on_entered_edit_mode() -> void:
	%SettingsButton.visible = true


func _on_exited_edit_mode() -> void:
	%SettingsButton.visible = false


func _on_settings_button_pressed() -> void:
	_macroboard.edit_config()


func _on_sidebar_visibility_changed() -> void:
	visible = GlobalSignals.sidebar_visible


# Applies the global "Sidebar color"/"Sidebar position"/"Sidebar thickness"
# settings: recolors this sidebar, anchors it to the configured edge and flips
# its buttons between a vertical or horizontal row.
func _apply_config() -> void:
	var data: Dictionary = ConfigLoader.get_config()
	var pos: SidebarPosition = data["sidebar_position"]

	_bg_style.bg_color = Color.hex(data["sidebar_color"])

	_apply_sidebar_anchors(pos, data["sidebar_thickness"])
	_apply_macroboard_orientation(is_horizontal_sidebar_position(pos))


# Keeps the board's button grid oriented along the sidebar: swapping between a
# vertical rail and a horizontal bar swaps columns/rows so the same buttons end
# up in a single row/column instead of getting cut off or leaving empty slots.
func _apply_macroboard_orientation(horizontal: bool) -> void:
	if horizontal == _last_horizontal:
		return
	_last_horizontal = horizontal

	var columns_object: Config.ConfigObject = _macroboard.config.get_object("columns")
	var rows_object: Config.ConfigObject = _macroboard.config.get_object("rows")
	var columns: int = columns_object.get_value()
	var rows: int = rows_object.get_value()

	columns_object.set_value(rows)
	rows_object.set_value(columns)
	_macroboard.config.save()
	_macroboard.handle_config()


func _apply_sidebar_anchors(pos: SidebarPosition, thickness: float) -> void:
	match pos:
		SidebarPosition.LEFT:
			set_anchors_and_offsets_preset(PRESET_LEFT_WIDE)
			offset_right = thickness
		SidebarPosition.RIGHT:
			set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE)
			offset_left = -thickness
		SidebarPosition.TOP:
			set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
			offset_bottom = thickness
		SidebarPosition.BOTTOM:
			set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
			offset_top = -thickness

	%VBox.vertical = not is_horizontal_sidebar_position(pos)
