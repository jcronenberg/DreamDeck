extends Resource
class_name Config
# TODO add an array type
# _config = Config.new([{"TYPE": "BOOL", "KEY": "Test Bool", "DEFAULT_VALUE": false, "DESCRIPTION": "[code]Testing code[/code]\n[indent]testing next indent level[/indent]\ntesting"},
# 	{"TYPE": "INT", "KEY": "Test Int", "DEFAULT_VALUE": 4, "DESCRIPTION": "multiple\nlines"},
# 	{"TYPE": "STRING", "KEY": "Test String", "DEFAULT_VALUE": "testing", "DESCRIPTION": "[color=green]testing color[/color]"},
# 	{"TYPE": "ENUM", "KEY": "Test Enum: Default -1", "DEFAULT_VALUE": -1, "ENUM": test},
# 	{"TYPE": "ENUM", "KEY": "Test Enum: Default test1", "DEFAULT_VALUE": test.test1, "ENUM": test, "DESCRIPTION": "[b]testing bold[/b]\n[i]testing italics[/i]\n[b][i]testing bold italics[/i][/b]\n[s]testing strikethrough[/s]"},
# 	{"TYPE": "FLOAT", "KEY": "Test Float", "DEFAULT_VALUE": 4}], "local_config/test.json")

signal config_changed

var _config: Array[ConfigObject]
var path: String
var filename: String


func _init(base_config: Array[Dictionary], initial_path: String = ""):
	_config = _generate_objects(base_config)
	if initial_path == "":
		return
	path = initial_path.get_base_dir() + "/"
	filename = initial_path.trim_prefix(path)


func load_config():
	if not path:
		return

	ConfLib.ensure_dir_exists(path)
	# ConfLib.conf_merge(config, ConfLib.load_config(path + filename).duplicate(true))
	var loaded_config: Variant = ConfLib.load_config(path + filename)
	if not loaded_config:
		loaded_config = {}
	apply_dict(loaded_config)


func apply_dict(dict: Dictionary):
	for item in dict:
		var object = _get_object(item)
		if object:
			object.set_value(dict[item])

	emit_signal("config_changed")


func save() -> bool:
	if not path:
		return false

	ConfLib.ensure_dir_exists(path)
	return ConfLib.save_config(path + filename, get_as_dict())


func get_as_dict() -> Dictionary:
	var ret_dict: Dictionary = {}
	for object in _config:
		ret_dict.merge(object.serialize())

	return ret_dict


# TODO private?
func _get_object(key: String) -> ConfigObject:
	for object in _config:
		if object.get_key() == key:
			return object

	return null


func _generate_objects(config: Array[Dictionary]) -> Array[ConfigObject]:
	var objects: Array[ConfigObject] = []
	for item in config:
		match item["TYPE"]:
			"BOOL":
				objects.append(BoolObject.new(item))
			"INT":
				objects.append(IntObject.new(item))
			"FLOAT":
				objects.append(FloatObject.new(item))
			"STRING":
				objects.append(StringObject.new(item))
			"ENUM":
				objects.append(EnumObject.new(item))

	return objects


func generate_editor() -> ConfigEditor:
	return ConfigEditor.new(self)


class ConfigObject:
	var _key: String
	var _description: String

	func _init(dict: Dictionary):
		deserialize(dict)

	func get_key():
		return _key

	func set_key(value):
		_key = value

	func get_description():
		return _description

	func set_description(value):
		_description = value

	func get_value():
		pass

	func set_value(_value):
		pass

	func serialize() -> Dictionary:
		return {}

	func deserialize(dict: Dictionary):
		_key = dict["KEY"]
		if dict.has("DESCRIPTION"):
			_description = dict["DESCRIPTION"]


class BoolObject extends ConfigObject:
	var _value: bool

	func get_value() -> bool:
		return _value

	func set_value(value: bool):
		_value = value

	func serialize() -> Dictionary:
		return {_key: _value}

	func deserialize(dict: Dictionary):
		super(dict)
		_value = dict["DEFAULT_VALUE"]


class IntObject extends ConfigObject:
	var _value: int

	func get_value() -> int:
		return _value

	func set_value(value: int):
		_value = value

	func serialize() -> Dictionary:
		return {_key: _value}

	func deserialize(dict: Dictionary):
		super(dict)
		_value = dict["DEFAULT_VALUE"]


class FloatObject extends ConfigObject:
	var _value: float

	func get_value() -> float:
		return _value

	func set_value(value: float):
		_value = value

	func serialize() -> Dictionary:
		return {_key: _value}

	func deserialize(dict: Dictionary):
		super(dict)
		_value = dict["DEFAULT_VALUE"]


class StringObject extends ConfigObject:
	var _value: String

	func get_value() -> String:
		return _value

	func set_value(value: String):
		_value = value

	func serialize() -> Dictionary:
		return {_key: _value}

	func deserialize(dict: Dictionary):
		super(dict)
		_value = dict["DEFAULT_VALUE"]


class EnumObject extends ConfigObject:
	var _value: int
	var _enum_dict: Dictionary

	func _init(dict: Dictionary):
		super(dict)

		_enum_dict = dict["ENUM"]
		_value = dict["DEFAULT_VALUE"]

	func get_value() -> int:
		return _value

	func set_value(value: int):
		_value = value

	func get_enum_dict() -> Dictionary:
		return _enum_dict

	func serialize() -> Dictionary:
		return {_key: _value}

	func deserialize(dict: Dictionary):
		super(dict)
		_value = dict["DEFAULT_VALUE"]


class ConfigEditor extends VBoxContainer:
	var _config_ref: Config
	var _object_editors: Array[VariantEditor] = []

	func _init(config: Config):
		_config_ref = config

		set_anchors_preset(PRESET_FULL_RECT)
		set("theme_override_constants/separation", 20)

		for object in _config_ref._config:
			if object is BoolObject:
				_object_editors.append(BoolEditor.new(object))
			elif object is IntObject:
				_object_editors.append(IntEditor.new(object))
			elif object is FloatObject:
				_object_editors.append(FloatEditor.new(object))
			elif object is StringObject:
				_object_editors.append(StringEditor.new(object))
			elif object is EnumObject:
				_object_editors.append(EnumEditor.new(object))

		for editor in _object_editors:
			add_child(editor)


	func apply():
		_config_ref.apply_dict(serialize())


	func serialize() -> Dictionary:
		var save_dict: Dictionary = {}
		for child in get_children():
			save_dict[child.get_key()] = child.get_value()

		return save_dict


	# TODO save on apply?
	func save():
		_config_ref.save()


	func get_editor(key: String) -> VariantEditor:
		for editor in _object_editors:
			if key == editor.get_key():
				return editor

		return null


class VariantEditor extends HBoxContainer:
	var _key_label: Label
	var _description_label: RichTextLabel


	func _init(object: ConfigObject):
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		_key_label = Label.new()
		vbox.add_child(_key_label)
		set_key(object.get_key())

		_description_label = RichTextLabel.new()
		_description_label.fit_content = true
		_description_label.scroll_active = false
		_description_label.bbcode_enabled = true
		vbox.add_child(_description_label)
		set_description(object.get_description())

		add_child(vbox)


	func set_description(description: String):
		# Making everything just [indent] is a bit of a hack, but works visually
		_description_label.text = "[indent]" + description + "[/indent]"


	func set_key(value: String):
		_key_label.text = value


	func get_key() -> String:
		return _key_label.text


	func set_value(_value):
		pass


	func get_value():
		pass


class BoolEditor extends VariantEditor:
	var _value_editor: CheckBox

	func _init(object: BoolObject):
		super(object)

		_value_editor = CheckBox.new()
		_value_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_value_editor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(_value_editor)
		set_value(object.get_value())


	func set_value(value: bool):
		_value_editor.button_pressed = value


	func get_value() -> bool:
		return _value_editor.button_pressed


class IntEditor extends VariantEditor:
	var _value_editor: SpinBox

	func _init(object: IntObject):
		super(object)

		_value_editor = SpinBox.new()
		_value_editor.step = 1
		_value_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_value_editor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(_value_editor)
		set_value(object.get_value())


	func set_value(value: int):
		_value_editor.value = value


	func get_value() -> int:
		return int(_value_editor.value)


class FloatEditor extends VariantEditor:
	var _value_editor: SpinBox

	func _init(object: FloatObject):
		super(object)

		_value_editor = SpinBox.new()
		_value_editor.step = 0.00001
		_value_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_value_editor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(_value_editor)
		set_value(object.get_value())


	func set_value(value: float):
		_value_editor.value = value


	func get_value() -> float:
		return _value_editor.value


class StringEditor extends VariantEditor:
	var _value_editor: LineEdit

	func _init(object: StringObject):
		super(object)

		_value_editor = LineEdit.new()
		_value_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_value_editor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(_value_editor)
		set_value(object.get_value())


	func set_value(value: String):
		_value_editor.text = value


	func get_value() -> String:
		return _value_editor.text


class EnumEditor extends VariantEditor:
	var _value_editor: OptionButton
	var _enum_dict: Dictionary

	func _init(object: EnumObject):
		super(object)

		_enum_dict = object.get_enum_dict()
		_value_editor = OptionButton.new()
		_value_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_value_editor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(_value_editor)

		var clear_button = Button.new()
		clear_button.text = "X"
		clear_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(clear_button)
		clear_button.connect("pressed", _on_clear_button_pressed)

		setup_value_editor()
		set_value(object.get_value())


	func setup_value_editor():
		_value_editor.clear()
		for key in _enum_dict:
			_value_editor.add_item(key)


	func set_value(value: int):
		if value == -1:
			_value_editor.select(-1)
			return

		var id: int = -1
		var value_string = _enum_dict.find_key(value)
		if value_string == null:
			push_error("Value not found in enum")
			return

		for i in _value_editor.get_item_count():
			if _value_editor.get_item_text(i) == value_string:
				id = i

		if id == -1:
			push_error("Value not found in enum value editor")
			return

		_value_editor.select(id)


	func set_enum_dict(dict: Dictionary):
		_enum_dict = dict
		setup_value_editor()


	func get_value_editor() -> OptionButton:
		return _value_editor


	func get_value():
		if _value_editor.get_selected_id() == -1:
			return -1

		return _enum_dict.get(_value_editor.get_item_text(_value_editor.get_selected_id()))


	func get_value_string() -> String:
		var value: int = get_value()
		if value == -1:
			return ""

		for item in _enum_dict:
			if _enum_dict[item] == value:
				return item

		return ""


	func _on_clear_button_pressed():
		_value_editor.select(-1)
