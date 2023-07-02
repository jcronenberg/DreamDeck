extends Button


func init(name: String, dict: Dictionary):
	text = name
	add_submenu(dict)


func _on_OptionButton_pressed():
	toggle_submenu()


# Takes a dict and recursively adds all keys with corresponding buttons
func add_submenu(dict):
	$SubmenuBg.rect_position.x = rect_size.x
	for key in dict.keys():
		var new_button
		match typeof(dict[key]):
			TYPE_BOOL:
				new_button = load("res://scenes/MainMenu/OptionToggle.tscn").instance()
				new_button.init(key, dict[key])
			TYPE_INT,TYPE_REAL,TYPE_STRING:
				new_button = load("res://scenes/MainMenu/OptionLineEdit.tscn").instance()
				new_button.init(key, dict[key])
			TYPE_DICTIONARY:
				new_button = load("res://scenes/MainMenu/SubmenuButton.tscn").instance()
				new_button.init(key, dict[key])
			_:
				push_warning("Submenu: Type not supported")

		$SubmenuBg/OptionSeparator.add_child(new_button)

		# Increase SubmenuBg size to account for new button
		$SubmenuBg.rect_min_size.y = $SubmenuBg.rect_min_size.y + 60

		# If button is larger than default size we need to adjust min size
		change_submenu_size(new_button.rect_size.x)


# Resets submenu to original state, so that a different submenu can be added
func clear_submenu():
	for child in $SubmenuBg/OptionSeparator.get_children():
		child.queue_free()

	$SubmenuBg.rect_min_size.y = 0
	$SubmenuBg.rect_min_size.x = 0


# Shows submenu if button is of type SUBMENU
func toggle_submenu():
	hide_other_open_submenu()

	if $SubmenuBg.visible:
		hide_submenu()
	else:
		$SubmenuBg.visible = true


# Recursive function to hide all submenus
func hide_submenu():
	for child in $SubmenuBg/OptionSeparator.get_children():
		if child.has_method("hide_submenu"):
			child.hide_submenu()

	$SubmenuBg.visible = false


# Checks if another submenu on the same level is open and closes it
func hide_other_open_submenu():
	for child in get_parent().get_children():
		if child != self \
			and child.has_method("hide_submenu") \
			and child.get_node("SubmenuBg").visible:
			child.hide_submenu()


func change_submenu_size(new_x: int):
	if $SubmenuBg.rect_min_size.x < new_x:
		$SubmenuBg.rect_min_size.x = new_x

		for child in $SubmenuBg/OptionSeparator.get_children():
			if child.has_node("SubmenuBg"):
				child.get_node("SubmenuBg").rect_position.x = new_x


func return_key() -> String:
	return text


func construct_dict() -> Dictionary:
	var ret_dict := {}
	for child in $SubmenuBg/OptionSeparator.get_children():
		var key = child.return_key()
		if child.has_method("return_value"):
			ret_dict[key] = child.return_value()
			if ret_dict[key] == null:
				ret_dict.erase(key)
		elif child.has_method("construct_dict"):
			# tmp
			var new_dict = child.construct_dict()
			if new_dict:
				ret_dict[key] = new_dict

	return ret_dict


func _on_rect_changed():
	var parent_submenu = get_node("../../..")
	if parent_submenu.has_method("change_submenu_size"):
		get_node("../../..").change_submenu_size(rect_size.x)
