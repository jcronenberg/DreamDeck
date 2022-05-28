extends Node

var data

func _ready():
	var config_file = File.new()

	config_file.open("user://config.json", File.READ)
	var config_json = JSON.parse(config_file.get_as_text())

	# Check if parsing the file was successful
	if config_json.error == OK:
		data = config_json.result
	else:
		print("Error parsing config file")
		return

func get_config_data():
	return data
