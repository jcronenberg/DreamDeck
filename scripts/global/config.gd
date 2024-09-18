extends Resource
class_name Config
## A helper class for configs.
##
## Includes several helper functions and also the ability to automatically generate
## a default editor for the config.[br]
## [br]
## Example usage:
##
## [codeblock]
## config: Config = Config.new()
## config.add_bool("Example bool", "example_bool", false, "[code]Example code[/code]\n[b]Another line[/b]")
## config.add_string("Example string", "example string", "Example default value")
## [/codeblock]

## Emitted when the config changed
signal config_changed

var _path: String:
	set = set_config_path
var _config: Array[ConfigObject]:
	get = get_objects


## Loads the config from disk.
## If no path was set, it doesn't do anything.
func load_config():
	if not _path:
		return

	ConfLib.ensure_dir_exists(_path.get_base_dir())
	var loaded_config: Variant = ConfLib.load_config(_path)
	if not loaded_config:
		loaded_config = {}
	apply_dict(loaded_config)


## Applies a simple key value [Dictionary] to the config.[br]
## [param dict] should be for example:
## [code]{"Example Int": -1, "Example String": "Foo"}[/code].
func apply_dict(dict: Dictionary):
	for item in dict:
		var object = get_object(item)

		# FIXME temporary migration for config label
		if not object:
			for config_object in _config:
				if config_object.get_label() == item:
					object = config_object
					break

		if object:
			object.set_value(dict[item])

	config_changed.emit()


## Saves the config to the specified path. Returns false if saving failed.
## If no path was provided it simply returns false.
func save() -> bool:
	if not _path:
		return false

	ConfLib.ensure_dir_exists(_path.get_base_dir())
	return ConfLib.save_config(_path, get_as_dict())


## Returns the config as a [Dictionary].
## Note that this is not the definition dictionary but a simple dict
## containing just the key and value.[br]
## Example return value: [code]{"Example Int": -1, "Example String": "Foo"}[/code].
func get_as_dict() -> Dictionary:
	var ret_dict: Dictionary = {}
	for object in _config:
		ret_dict.merge(object.serialize())

	return ret_dict


## Generates and returns a [Config.ConfigEditor] for this config.
func generate_editor() -> ConfigEditor:
	return ConfigEditor.new(self)


## Add a object.
func add_object(object: ConfigObject) -> void:
	_config.append(object)


## Adds a bool object.[br]
## [param label]: User facing name of this object when editing[br]
## [param key]: Key string for the object (Will be what it is saved as on disk and also what you
## get when running [method get_as_dict])[br]
## [param value]: Default value[br]
## [param description](Optional): Description for what this config object does
func add_bool(label: String, key: String, value: bool, description: String = "") -> void:
	_config.append(BoolObject.new(label, key, value, description))


## Adds a int object.[br]
## [param label]: User facing name of this object when editing[br]
## [param key]: Key string for the object (Will be what it is saved as on disk and also what you
## get when running [method get_as_dict])[br]
## [param value]: Default value[br]
## [param description](Optional): Description for what this config object does
func add_int(label: String, key: String, value: int, description: String = "") -> void:
	_config.append(IntObject.new(label, key, value, description))


## Adds a float object.[br]
## [param label]: User facing name of this object when editing[br]
## [param key]: Key string for the object (Will be what it is saved as on disk and also what you
## get when running [method get_as_dict])[br]
## [param value]: Default value[br]
## [param description](Optional): Description for what this config object does
func add_float(label: String, key: String, value: float, description: String = "") -> void:
	_config.append(FloatObject.new(label, key, value, description))


## Adds a string object.[br]
## [param label]: User facing name of this object when editing[br]
## [param key]: Key string for the object (Will be what it is saved as on disk and also what you
## get when running [method get_as_dict])[br]
## [param value]: Default value[br]
## [param description](Optional): Description for what this config object does
func add_string(label: String, key: String, value: String, description: String = "") -> void:
	_config.append(StringObject.new(label, key, value, description))


## Adds a enum object.[br]
## [param label]: User facing name of this object when editing[br]
## [param key]: Key string for the object (Will be what it is saved as on disk and also what you
## get when running [method get_as_dict])[br]
## [param value]: Default value[br]
## [param enum_dict]: All available values for the enum in a [Dictionary].[br]
## Gdscript's [code]enum[/code] automatically generates this enum. See example below.[br]
## [param description](Optional): Description for what this config object does[br]
## Example:
## [codeblock]
## enum Example {ENUM_VALUE1, ENUM_VALUE2}
## config.add_enum("Example Enum", Example.ENUM_VALUE1, Example)
## [/codeblock]
func add_enum(label: String, key: String, value: int, enum_dict: Dictionary, description: String = "") -> void:
	_config.append(EnumObject.new(label, key, value, enum_dict, description))


## Adds a string array object.[br]
## This is useful if you want to store a string that can only be predetermined values.
## [param label]: User facing name of this object when editing[br]
## [param key]: Key string for the object (Will be what it is saved as on disk and also what you
## get when running [method get_as_dict])[br]
## [param value]: Default value[br]
## [param string_array]: All available values to pick from[br]
## [param description](Optional): Description for what this config object does[br]
func add_string_array(label: String, key: String, value: String, string_array: Array[String], description: String = "") -> void:
	_config.append(StringArrayObject.new(label, key, value, string_array, description))


## Clears the config of all objects.
func clear_objects() -> void:
	_config = []


## Get a [Config.ConfigObject] by [param key].
func get_object(key: String) -> ConfigObject:
	for object in _config:
		if object.get_key() == key:
			return object

	return null


## Get all objects of the config.
func get_objects() -> Array[ConfigObject]:
	return _config


## Set the path of the config.
func set_config_path(path: String) -> void:
	_path = path


class ConfigObject:
	var _label: String:
		get = get_label, set = set_label
	var _key: String:
		get = get_key, set = set_key
	var _description: String:
		get = get_description, set = set_description


	func _init(label: String, key: String, description: String = ""):
		_label = label
		_key = key
		if description != "":
			_description = description


	func get_label() -> String:
		return _label


	func set_label(value: String) -> void:
		_label = value


	func get_key() -> String:
		return _key


	func set_key(value: String) -> void:
		_key = value


	func get_description() -> String:
		return _description


	func set_description(value: String) -> void:
		_description = value


	func get_value() -> Variant:
		return null


	func set_value(_value) -> void:
		pass


	func serialize() -> Dictionary:
		return {}


class BoolObject extends ConfigObject:
	var _value: bool:
		set = set_value, get = get_value


	func _init(label: String, key: String, value: bool, description: String = ""):
		super(label, key, description)
		_value = value


	func get_value() -> bool:
		return _value


	func set_value(value: bool):
		_value = value


	func serialize() -> Dictionary:
		return {_key: _value}


class IntObject extends ConfigObject:
	var _value: int:
		set = set_value, get = get_value


	func _init(label: String, key: String, value: int, description: String = ""):
		super(label, key, description)
		_value = value


	func get_value() -> int:
		return _value


	func set_value(value: int) -> void:
		_value = value


	func serialize() -> Dictionary:
		return {_key: _value}


class FloatObject extends ConfigObject:
	var _value: float:
		set = set_value, get = get_value


	func _init(label: String, key: String, value: float, description: String = ""):
		super(label, key, description)
		_value = value


	func get_value() -> float:
		return _value


	func set_value(value: float):
		_value = value


	func serialize() -> Dictionary:
		return {_key: _value}


class StringObject extends ConfigObject:
	var _value: String:
		set = set_value, get = get_value


	func _init(label: String, key: String, value: String, description: String = ""):
		super(label, key, description)
		_value = value


	func get_value() -> String:
		return _value


	func set_value(value: String):
		_value = value


	func serialize() -> Dictionary:
		return {_key: _value}


class EnumObject extends ConfigObject:
	var _value: int:
		set = set_value, get = get_value
	var _enum_dict: Dictionary:
		get = get_enum_dict


	func _init(label: String, key: String, value: int, enum_dict: Dictionary, description: String = ""):
		super(label, key, description)
		_value = value
		_enum_dict = enum_dict


	func get_value() -> int:
		return _value


	func set_value(value: int):
		_value = value


	func get_enum_dict() -> Dictionary:
		return _enum_dict


	func serialize() -> Dictionary:
		return {_key: _value}


class StringArrayObject extends ConfigObject:
	var _value: String:
		set = set_value, get = get_value
	var _string_array: Array[String]:
		set = set_string_array, get = get_string_array


	func _init(label: String, key: String, value: String, string_array: Array[String], description: String = ""):
		super(label, key, description)
		_value = value
		_string_array = string_array


	func get_value() -> String:
		return _value


	func set_value(value: String):
		if value in _string_array:
			_value = value


	func get_string_array() -> Array[String]:
		return _string_array


	func set_string_array(array: Array[String]) -> void:
		_string_array = array


	func serialize() -> Dictionary:
		return {_key: _value}


## An editor for a [Config]
##
## The editor is a [VBoxContainer] that contains a row for each object
## inside a [Config]. Each row allows a user to edit the values for the objects.[br]
## A editor is always linked to a [Config].
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
			elif object is StringArrayObject:
				_object_editors.append(StringArrayEditor.new(object))

		for editor in _object_editors:
			add_child(editor)


	## Applies the current values to the config via [method Config.apply_dict].
	func apply():
		_config_ref.apply_dict(serialize())


	## Returns a key value [Dictionary] for the current values.
	func serialize() -> Dictionary:
		var save_dict: Dictionary = {}
		for child in get_children():
			save_dict[child.get_key()] = child.get_value()

		return save_dict


	## Saves the config via [method Config.save].
	func save():
		_config_ref.save()


	## Get a specific editor by [param key].
	## Useful if you e.g. need to change some values for a editor after
	## the the editor was already initialized.
	func get_editor(key: String) -> VariantEditor:
		for editor in _object_editors:
			if key == editor.get_key():
				return editor

		return null


	func set_values(values: Array[Variant]) -> void:
		if values.size() > _object_editors.size():
			push_error("Trying to set too many values for Config")
			return
		for i in values.size():
			_object_editors[i].set_value(values[i])


	func get_values() -> Array[Variant]:
		var ret_arr: Array[Variant] = []
		for object_editor in _object_editors:
			ret_arr.append(object_editor.get_value())

		return ret_arr


class VariantEditor extends HBoxContainer:
	var _key: String
	var _name_label: Label = Label.new()
	var _description_label: RichTextLabel


	func _init(object: ConfigObject):
		_key = object.get_key()

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		vbox.add_child(_name_label)
		set_label(object.get_label())

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


	func set_label(value: String):
		_name_label.text = value


	func get_key() -> String:
		return _key


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


class StringArrayEditor extends VariantEditor:
	var _value_editor: OptionButton
	var _string_array: Array[String]


	func _init(object: StringArrayObject) -> void:
		super(object)

		_string_array = object.get_string_array()
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


	func setup_value_editor() -> void:
		_value_editor.clear()
		for string in _string_array:
			_value_editor.add_item(string)


	func set_value(value: String) -> void:
		if not value in _string_array:
			_value_editor.select(-1)
			return

		for i in _value_editor.get_item_count():
			if _value_editor.get_item_text(i) == value:
				_value_editor.select(i)


	func set_string_array(array: Array[String]) -> void:
		_string_array = array
		setup_value_editor()


	func get_value_editor() -> OptionButton:
		return _value_editor


	func get_value() -> String:
		if _value_editor.get_selected_id() == -1:
			return ""

		return _value_editor.get_item_text(_value_editor.get_selected_id())


	func _on_clear_button_pressed() -> void:
		_value_editor.select(-1)
