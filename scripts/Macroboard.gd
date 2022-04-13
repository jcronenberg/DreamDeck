extends Control

func _ready():
	load_from_config()
	#debug
	var save_state = save()
	var config_file = File.new()
	config_file.open("user://config.json", File.READ_WRITE)
	#print(JSON.print(save_state, "\t"))
	config_file.store_string(JSON.print(save_state, "\t"))
	#var output_json = JSON.parse(config_file.get_as_text())
	#print(output_json.result)

func load_from_config():
	var macro_row = load("res://scenes/MacroRow.tscn")
	var app_button = load("res://scenes/AppButton.tscn")
	var data
	var config_file = File.new()

	config_file.open("user://config.json", File.READ)
	var config_json = JSON.parse(config_file.get_as_text())

	# Check if parsing the file was successful
	if config_json.error == OK:
		data = config_json.result
		print(data)
	else:
		print("Error parsing config file")
		return

	# Iterate through rows in data
	for row in data["macroboard"].values():
		# Instance row so we can modify it
		var cur_row = macro_row.instance()

		# Iterate through buttons in row
		for button in row.values():
			# Instance button so we can modify it
			var new_button = app_button.instance()

			# Iterate through all values that need to be set in button
			for key in button.keys():
				# Only set attribute if value is set (may be unnecessary)
				if button[key]:
					new_button.set(key, button[key])

			# Add modified button to current row
			cur_row.add_child(new_button)

		# Add row to scene
		$RowSeparator.add_child(cur_row)

func save():
	var save_dict = {
		"macroboard" : {}
	}
	var row_count = 0
	for rows in $RowSeparator.get_children():
		save_dict["macroboard"]["row" + str(row_count)] = {}
		var button_count = 0
		for button in rows.get_children():
			save_dict["macroboard"]["row" + str(row_count)]["button" + str(button_count)] = button.save()
			button_count += 1
		row_count += 1
	return save_dict
