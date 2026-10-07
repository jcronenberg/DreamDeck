class_name ClaudeStatusPluginLoader
extends PluginLoaderBase


func _init() -> void:
	plugin_name = "Claude Status"
	scenes = {
		"Claude Status": "res://plugins/claude_status/src/claude_status_panel.tscn",
		"Claude Usage": "res://plugins/claude_status/src/claude_usage_panel.tscn",
	}
