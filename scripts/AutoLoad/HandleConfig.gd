extends Node


onready var config_loader = get_node("/root/ConfigLoader")


func _ready():
	handle_config()
	get_node("/root/GlobalSignals").connect("global_config_changed", self, "_on_global_config_changed")


func _on_global_config_changed():
	handle_config()


func handle_config():
	var config_data = config_loader.get_config()
	get_tree().get_root().transparent_bg = config_data["Transparent Background"]
