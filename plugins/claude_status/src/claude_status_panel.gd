extends ClaudeStatusSceneBase
## Shows a [ClaudeStopLight] per Claude Code session.
##
## Expected format:
## [codeblock]
## {"sessions": {"<id>": {"name": "", "status": "", "prompt": "", "detail": "", "updated_at": ""}}}
## [/codeblock]

# Values are saved in the config, so new ones go at the end.
enum Caption { NOTHING, SESSION_ID, PROMPT, DETAIL, NAME }

const STATUS_LAMPS: Dictionary = {
	"working": ClaudeStopLight.Lamp.GREEN,
	"waiting": ClaudeStopLight.Lamp.YELLOW,
	"stopped": ClaudeStopLight.Lamp.RED,
}
const CAPTION_OPTIONS: Dictionary = {
	"Nothing": Caption.NOTHING,
	"Session ID": Caption.SESSION_ID,
	"Name": Caption.NAME,
	"Prompt": Caption.PROMPT,
	"Detail": Caption.DETAIL,
}

var _max_sessions: int = 4
var _caption: Caption = Caption.PROMPT
# Session ids in the order they were first seen, so lights keep their place instead of
# reordering every time a session's updated_at changes.
var _session_order: Array[String] = []

var _lights_box: HBoxContainer
var _hint_label: Label


func _init() -> void:
	super()
	config.add_int(
		"Max sessions",
		"max_sessions",
		4,
		(
			"Maximum amount of sessions shown; "
			+ "if there are more, the most recently updated ones are shown"
		)
	)
	config.add_dict(
		"Caption", "caption", Caption.PROMPT, CAPTION_OPTIONS, "What is shown below each stop light"
	)


func _ready() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)

	_lights_box = HBoxContainer.new()
	_lights_box.add_theme_constant_override("separation", 8)
	margin.add_child(_lights_box)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(_hint_label)

	super()


func handle_config() -> void:
	var data: Dictionary = config.get_as_dict()
	_max_sessions = maxi(data["max_sessions"], 1)
	_caption = data["caption"]
	super()


func _show_status(status: Dictionary) -> void:
	var sessions: Variant = status.get("sessions", {})
	if not sessions is Dictionary:
		sessions = {}
	_show_sessions(_select_sessions(sessions), sessions, "No Claude Code sessions")


func _show_hint(message: String) -> void:
	_show_sessions([], {}, message)


# Picks the most recently updated sessions and returns them in first-seen order.
func _select_sessions(sessions: Dictionary) -> Array[String]:
	var by_recency: Array[String] = []
	for id in sessions:
		if sessions[id] is Dictionary:
			by_recency.append(str(id))
	# updated_at is ISO 8601 UTC, so it sorts correctly as a string.
	by_recency.sort_custom(
		func(a: String, b: String) -> bool:
			return str(sessions[a].get("updated_at", "")) > str(sessions[b].get("updated_at", ""))
	)
	# assign() since slice()/filter() return untyped arrays.
	var selected: Array[String] = []
	selected.assign(by_recency.slice(0, _max_sessions))

	_session_order.assign(_session_order.filter(func(id: String) -> bool: return sessions.has(id)))
	# Oldest first, so sessions that already exist on startup keep a sensible order.
	for i in range(selected.size() - 1, -1, -1):
		if not _session_order.has(selected[i]):
			_session_order.append(selected[i])

	var shown: Array[String] = []
	shown.assign(_session_order.filter(func(id: String) -> bool: return selected.has(id)))
	return shown


func _show_sessions(ids: Array[String], sessions: Dictionary, hint: String) -> void:
	while _lights_box.get_child_count() > ids.size():
		var extra: Node = _lights_box.get_child(-1)
		_lights_box.remove_child(extra)
		extra.queue_free()
	while _lights_box.get_child_count() < ids.size():
		_lights_box.add_child(ClaudeStopLight.new())

	for i in ids.size():
		var session: Dictionary = sessions[ids[i]]
		var status: String = str(session.get("status", ""))
		var light: ClaudeStopLight = _lights_box.get_child(i)
		light.set_session(
			STATUS_LAMPS.get(status, ClaudeStopLight.Lamp.NONE), _get_caption(ids[i], session)
		)
		light.set_caption_visible(_caption != Caption.NOTHING)

	_hint_label.text = hint
	_hint_label.visible = ids.is_empty()


func _get_caption(id: String, session: Dictionary) -> String:
	var caption: Variant = ""
	match _caption:
		Caption.SESSION_ID:
			caption = id
		Caption.PROMPT:
			caption = session.get("prompt", "")
		Caption.DETAIL:
			caption = session.get("detail", "")
		Caption.NAME:
			caption = session.get("name", "")
	# The hooks write null for fields they have no value for yet.
	return caption if caption is String else ""
