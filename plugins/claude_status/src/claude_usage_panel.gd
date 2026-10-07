extends ClaudeStatusSceneBase
## Shows a [ClaudeUsageBar] for the 5-hour and the weekly Claude Code rate limit.
##
## Expected format:
## [codeblock]
## {"rate_limits": {"five_hour": {"used_percentage": 0, "resets_at": 0},
##                  "seven_day": {"used_percentage": 0, "resets_at": 0}}}
## [/codeblock]

const LIMITS: Dictionary = {"five_hour": "5-hour limit", "seven_day": "Weekly limit"}

var _bars: Dictionary = {}
var _bars_box: VBoxContainer
var _hint_label: Label


func _ready() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)

	_bars_box = VBoxContainer.new()
	_bars_box.add_theme_constant_override("separation", 8)
	margin.add_child(_bars_box)
	for key in LIMITS:
		_bars[key] = ClaudeUsageBar.new(LIMITS[key])
		_bars_box.add_child(_bars[key])

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(_hint_label)

	super()


# The countdowns tick even while the file stays unchanged.
func _refresh() -> void:
	super()
	for bar: ClaudeUsageBar in _bars.values():
		bar.refresh()


func _show_status(status: Dictionary) -> void:
	var rate_limits: Variant = status.get("rate_limits")
	if not rate_limits is Dictionary:
		rate_limits = {}

	# A missing limit still gets its bar, as nothing used, so the layout doesn't jump around.
	for key in LIMITS:
		var limit: Variant = rate_limits.get(key)
		if not limit is Dictionary:
			limit = {}
		var used: Variant = limit.get("used_percentage")
		var resets_at: Variant = limit.get("resets_at")
		_bars[key].set_usage(
			used if _is_number(used) else 0.0, int(resets_at) if _is_number(resets_at) else 0
		)

	_bars_box.visible = true
	_hint_label.visible = false


func _show_hint(message: String) -> void:
	_hint_label.text = message
	_hint_label.visible = true
	_bars_box.visible = false


static func _is_number(value: Variant) -> bool:
	return value is float or value is int
