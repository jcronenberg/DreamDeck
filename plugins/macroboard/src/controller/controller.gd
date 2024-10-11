class_name MacroboardController
extends PluginControllerBase

const DEFAULT_FONT_COLOR = Color(1, 1, 1)
const DEFAULT_BG_COLOR = Color(1, 1, 1, 0.11)
const DEFAULT_PRESSED_COLOR = Color(1, 1, 1, 0.196)
const THEME_TYPE_VARIATION = "MacroButton"

const macroboard_theme = preload("res://plugins/macroboard/themes/theme.tres")


func _init():
	plugin_name = "Macroboard"
	config.add_color("Normal background color", "bg_color", DEFAULT_BG_COLOR, "", false)
	config.add_color("Pressed background color", "pressed_color", DEFAULT_PRESSED_COLOR, "", false)
	config.add_color("Normal font color", "font_color", DEFAULT_FONT_COLOR, "", false)
	config.add_color("Pressed font color", "font_pressed_color", DEFAULT_FONT_COLOR, "", false)


func handle_config() -> void:
	var data = config.get_as_dict()

	if data.has("bg_color"):
		_set_default_bg_color(Color.hex(data["bg_color"]))
	else:
		_set_default_bg_color(DEFAULT_BG_COLOR)

	if data.has("pressed_color"):
		_set_default_pressed_color(Color.hex(data["pressed_color"]))
	else:
		_set_default_pressed_color(DEFAULT_PRESSED_COLOR)

	if data.has("font_color"):
		_set_default_font_color(Color.hex(data["font_color"]))
	else:
		_set_default_font_color(DEFAULT_FONT_COLOR)

	if data.has("font_pressed_color"):
		_set_default_font_pressed_color(Color.hex(data["font_pressed_color"]))
	else:
		_set_default_font_pressed_color(DEFAULT_FONT_COLOR)


func _set_default_bg_color(bg_color: Color) -> void:
	var bg_stylebox: StyleBoxFlat = macroboard_theme.get_stylebox("normal", THEME_TYPE_VARIATION)
	bg_stylebox.bg_color = bg_color
	var hover_stylebox: StyleBoxFlat = macroboard_theme.get_stylebox("hover", THEME_TYPE_VARIATION)
	hover_stylebox.bg_color = bg_color


func _set_default_pressed_color(pressed_color: Color) -> void:
	var pressed_stylebox: StyleBoxFlat = macroboard_theme.get_stylebox("pressed", THEME_TYPE_VARIATION)
	pressed_stylebox.bg_color = pressed_color


func _set_default_font_color(font_color: Color) -> void:
	macroboard_theme.set_color("font_color", THEME_TYPE_VARIATION, font_color)
	macroboard_theme.set_color("font_focus_color", THEME_TYPE_VARIATION, font_color)
	macroboard_theme.set_color("font_hover_color", THEME_TYPE_VARIATION, font_color)
	macroboard_theme.set_color("font_color", "MacroButtonLabel", font_color)


func _set_default_font_pressed_color(font_pressed_color: Color) -> void:
	macroboard_theme.set_color("font_pressed_color", THEME_TYPE_VARIATION, font_pressed_color)
	macroboard_theme.set_color("font_color", "MacroButtonLabelPressed", font_pressed_color)
