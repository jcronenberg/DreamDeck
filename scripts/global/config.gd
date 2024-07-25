extends Resource
class_name Config
## A helper class for configs.
##
## Includes several helper functions and also the ability to automatically generate
## a default editor for the config.[br]
## [br]
## It requires a definition of what the config is supposed to look like.
## [br]
## Definitions are an [Array] of [Dictionary] and the dictionaries need to contain certain
## keys.[br]
## [br]
## All entries need to contain at least:[br]
## "TYPE": The type of the entry, e.g. "BOOL"[br]
## "KEY": What name the entry should have.[br]
## "DEFAULT_VALUE": The default value of the entry.[br]
## [br]
## Optionally they can contain these:[br]
## "DESCRIPTION": A description that get's added below the name.
## This accepts bbcode formatted text.[br]
## [br]
## Here is a list of all available types:
##
## [codeblock]
## "BOOL": No additional properties.
## "INT": No additional properties.
## "FLOAT": No additional properties.
## "STRING": No additional properties.
## "ENUM":
##     "ENUM": The dictionary of the enum.
##             (You don't have to generate this dict, it is built into gdscript, see example)
## [/codeblock]
##
## Example:
##
## [codeblock]
## Config.new([
##     {"TYPE": "BOOL", "KEY": "Example Bool", "DEFAULT_VALUE": false, "DESCRIPTION": "[code]Example code[/code]\n[b]Another line[/b]"},
##     {"TYPE": "STRING", "KEY": "Example String", "DEFAULT_VALUE": "Example value"},
## ])
##
## # For enums
## enum Example {ENUM_VALUE1, ENUM_VALUE2}
## Config.new([{"TYPE": "ENUM", "KEY": "Example Enum", "DEFAULT_VALUE": Example.ENUM_VALUE1, "ENUM": Example}])
##
## # If you want to have the config saved to disk you must provide a path
## Config.new(DEFINITION, "your/path/")
## [/codeblock]

## Emitted when the config changed
signal config_changed

var _path: String
var _config: Array[ConfigObject]


func _init(config_definition: Array[Dictionary], path: String = ""):
	_config = _generate_objects(config_definition)
	if path == "":
		return
	_path = path


## Loads the config from disk.
## If no path was provided at initialization, it doesn't do anything.
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
		var object = _get_object(item)
		if object:
			object.set_value(dict[item])

	emit_signal("config_changed")


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


class ConfigObject:
	var _key: String:
		get = get_key, set = set_key
	var _description: String:
		get = get_description, set = set_description


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
	var _value: bool:
		set = set_value, get = get_value


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
	var _value: int:
		set = set_value, get = get_value


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
	var _value: float:
		set = set_value, get = get_value


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
	var _value: String:
		set = set_value, get = get_value


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
	var _value: int:
		set = set_value, get = get_value
	var _enum_dict: Dictionary:
		get = get_enum_dict


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
