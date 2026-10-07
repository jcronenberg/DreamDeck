class_name ClaudeStopLight
extends VBoxContainer
## A single stop light showing the status of one Claude Code session, with an
## optional caption below it.

enum Lamp { NONE = -1, RED, YELLOW, GREEN }

# Lamps are ordered top to bottom like a real stop light.
const LAMP_COLORS: Array[Color] = [Color("e5484d"), Color("f5c518"), Color("30a46c")]
const HOUSING_COLOR: Color = Color("1e1e1e")
# Width / height of the housing, kept regardless of the available space.
const HOUSING_ASPECT: float = 0.4
const LAMP_RADIUS_RATIO: float = 0.36
const UNLIT_DARKEN: float = 0.8

var _lit: Lamp = Lamp.NONE
var _housing: Control = Control.new()
var _caption: Label = Label.new()


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_housing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_housing.custom_minimum_size = Vector2(16, 40)
	_housing.draw.connect(_draw_housing)
	add_child(_housing)

	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# Lets long captions shrink with the panel instead of forcing it wider.
	_caption.custom_minimum_size.x = 1
	add_child(_caption)


func set_session(lit: Lamp, caption: String) -> void:
	_caption.text = caption
	if lit != _lit:
		_lit = lit
		_housing.queue_redraw()


func set_caption_visible(caption_visible: bool) -> void:
	_caption.visible = caption_visible


func _draw_housing() -> void:
	var available: Vector2 = _housing.size
	var housing_size: Vector2 = Vector2(available.y * HOUSING_ASPECT, available.y)
	if housing_size.x > available.x:
		housing_size = Vector2(available.x, available.x / HOUSING_ASPECT)
	var housing_rect: Rect2 = Rect2((available - housing_size) / 2, housing_size)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = HOUSING_COLOR
	style.set_corner_radius_all(int(housing_size.x * 0.3))
	_housing.draw_style_box(style, housing_rect)

	var cell_height: float = housing_size.y / LAMP_COLORS.size()
	var radius: float = minf(housing_size.x, cell_height) * LAMP_RADIUS_RATIO
	for i in LAMP_COLORS.size():
		var center: Vector2 = (
			housing_rect.position + Vector2(housing_size.x / 2, cell_height * (i + 0.5))
		)
		if i == _lit:
			_housing.draw_circle(center, radius * 1.2, Color(LAMP_COLORS[i], 0.3))
			_housing.draw_circle(center, radius, LAMP_COLORS[i])
		else:
			_housing.draw_circle(center, radius, LAMP_COLORS[i].darkened(UNLIT_DARKEN))
