class_name ClaudeUsageBar
extends VBoxContainer
## A bar showing how much of one Claude Code rate limit is used, and when it resets.

# Fill turns yellow, then red as the limit gets closer, in the stop light's colors.
const WARN_PERCENTAGE: float = 50.0
const CRITICAL_PERCENTAGE: float = 80.0
const CORNER_RADIUS: int = 6

var _used_percentage: float = 0.0
var _resets_at: int = 0

var _percentage_label: Label = Label.new()
var _bar: ProgressBar = ProgressBar.new()
var _reset_label: Label = Label.new()
var _fill_style: StyleBoxFlat = StyleBoxFlat.new()


func _init(title: String) -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var header: HBoxContainer = HBoxContainer.new()
	add_child(header)
	var title_label: Label = Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.custom_minimum_size.x = 1
	header.add_child(title_label)
	header.add_child(_percentage_label)

	var background_style: StyleBoxFlat = StyleBoxFlat.new()
	background_style.bg_color = ClaudeStopLight.HOUSING_COLOR
	background_style.set_corner_radius_all(CORNER_RADIUS)
	_fill_style.set_corner_radius_all(CORNER_RADIUS)
	_bar.add_theme_stylebox_override("background", background_style)
	_bar.add_theme_stylebox_override("fill", _fill_style)
	_bar.show_percentage = false
	_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bar.custom_minimum_size.y = 12
	add_child(_bar)

	_reset_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_reset_label.custom_minimum_size.x = 1
	add_child(_reset_label)


## [param resets_at] is a unix timestamp, or 0 if unknown.
func set_usage(used_percentage: float, resets_at: int) -> void:
	_used_percentage = used_percentage
	_resets_at = resets_at
	refresh()


## Updates the reset countdown, so call this periodically.
func refresh() -> void:
	var remaining: int = _resets_at - int(Time.get_unix_time_from_system())
	# A new window starts empty, and nothing writes newer numbers until Claude Code is used again.
	var used: float = _used_percentage if _resets_at == 0 or remaining > 0 else 0.0

	_bar.value = used
	_percentage_label.text = "%d%%" % roundi(used)
	_reset_label.text = "Resets in %s" % _format_duration(remaining) if remaining > 0 else ""

	var lamp: ClaudeStopLight.Lamp = ClaudeStopLight.Lamp.GREEN
	if used >= CRITICAL_PERCENTAGE:
		lamp = ClaudeStopLight.Lamp.RED
	elif used >= WARN_PERCENTAGE:
		lamp = ClaudeStopLight.Lamp.YELLOW
	_fill_style.bg_color = ClaudeStopLight.LAMP_COLORS[lamp]


static func _format_duration(seconds: int) -> String:
	var total_minutes: int = ceili(seconds / 60.0)
	var days: int = floori(total_minutes / 1440.0)
	var hours: int = floori(total_minutes / 60.0) % 24
	var minutes: int = total_minutes % 60
	if days > 0:
		return "%dd %dh" % [days, hours]
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	return "%dm" % minutes
