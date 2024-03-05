class_name ScrollTextLabel
extends Label
## A [Label] that scrolls text right to left if it clips parent size.
##
## This only works if the parent clips the text as it scrolls via
## changing it's position.[br]
## WARNING! It doesn't work if the text clips via [member Label.clip_text]
## and [member Label.clip_text] needs to be set to false.[br]
## Use [method ScrollTextLabel.set_new_text] to modify the text.
## Modifying the text directly will break position and size.


## Scroll speed of the text.
## This is dependent on the length of the text.
## It gets passed to the tween with the calculation:
## [code]text_length / scroll_speed[/code].
@export var scroll_speed: float = 5.0

## When text is scrolled what string should be appended to separate it.
@export var separator_string: String = ""

## When a full scroll happened a cooldown can be set before another scroll happens
@export var cooldown: float = 0.0

# The text set by set_new_text.
# As text gets changed but often the original value is needed.
var _original_text: String

var _tween


## Set text for the label.
## Use this instead of [method Label.set_text] or modifying [member Label.text]
## directly.
func set_new_text(value: String):
	if value == _original_text:
		return

	# Important to set text before reset_pos_and_size()
	text = value

	if _tween:
		_tween.kill()
		_tween = null
		_reset_pos_and_size()

	# Set internal state variables
	_original_text = value

	_init_scroll()


# Determines if scrolling should occur.
# If it should, initializes scrolling and repeats via recursive calling.
func _init_scroll():
	await get_tree().create_timer(cooldown).timeout
	# If a newer instance of the recursive function exists, the older should exit
	if _tween:
		return

	# Determining the size of the string feels so hacky lol
	if get_theme_default_font().get_string_size(_original_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			get_theme_default_font_size()).x <= get_parent_area_size().x:
		return

	# append separator string and the duplicate text
	set_text(_original_text + separator_string + _original_text)

	_tween = get_tree().create_tween()
	_tween.tween_property(self,
		"position",
		Vector2(-get_theme_default_font().get_string_size(_original_text + separator_string,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			get_theme_default_font_size()).x,
			position.y),
		_original_text.length() / scroll_speed)

	await _tween.finished
	_tween = null
	set_text(_original_text)
	_reset_pos_and_size()

	_init_scroll()


func _reset_pos_and_size():
	position.x = 0
	# Custom resizing since the label doesn't automatically reduce it's size again
	size.x = get_parent_area_size().x
