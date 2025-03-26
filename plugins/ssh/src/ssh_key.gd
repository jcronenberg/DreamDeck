class_name SSHKey
## Stores an SSH key.

## Emitted when the key config was updated.
## Note: not emitted on [method deserialize].
signal key_updated

enum CryptoTypes {
	ED25519,
	RSA,
}

enum KeyTypes {
	NEW_KEY,
	EXISTING_KEY,
}

## UUID of the key.
var uuid: String:
	set(value):
		uuid = value
		_config.get_object("uuid").set_value(value)
## Name of the key, must be unique as it is the identifier.
var name: String:
	set(value):
		name = value
		_config.get_object("name").set_value(value)
## Type of the key.
var type: KeyTypes:
	set(value):
		type = value
		_config.get_object("type").set_value(value)

## Data of the private key when [member type] is [code]NEW_KEY[/code].
var key_data: String:
	set(value):
		key_data = value
		_config.get_object("key_data").set_value(value)
## Path to the private key when [member type] is [code]EXISTING_KEY[/code].
var key_path: String:
	set(value):
		key_path = value
		_config.get_object("key_path").set_value(value)

# Internal config.
var _config: Config = _generate_default_config()


func _generate_default_config() -> Config:
	var config: Config = Config.new()

	config.add_string("UUID", "uuid", "")
	config.add_string("Name", "name", "")
	config.add_dict("Key type", "type", KeyTypes.NEW_KEY, KeyTypes)
	config.add_string("Key data", "key_data", "")
	config.add_file_path("Key path", "key_path", "")

	return config


func generate_editor() -> Config.ConfigEditor:
	var editor: Config.ConfigEditor = _config.generate_editor()

	# These editors are never supposed to be edited by a user on an existing key
	editor.get_editor("uuid").visible = false
	editor.get_editor("key_data").visible = false
	editor.get_editor("type").visible = false

	match type:
		KeyTypes.NEW_KEY:
			editor.get_editor("key_path").visible = false

	return editor


func apply_config() -> void:
	var dict: Dictionary = _config.get_as_dict()
	deserialize(dict)
	key_updated.emit()


## Fill values from [param dict].
func deserialize(dict: Dictionary) -> void:
	uuid = dict.uuid
	name = dict.name
	type = dict.type

	match type:
		KeyTypes.NEW_KEY:
			key_data = dict.key_data
		KeyTypes.EXISTING_KEY:
			key_path = dict.key_path


## Create a [Dictionary] with appropriate values.
## Note: Depending on the [member type],
## only either [member key_data] or [member key_path] will be saved.
## Will also emit an error when both are set, as this is not intended behaviour.
func serialize() -> Dictionary:
	var ret_dict: Dictionary = _config.get_as_dict()

	match type:
		KeyTypes.NEW_KEY:
			ret_dict.erase("key_path")
		KeyTypes.EXISTING_KEY:
			ret_dict.erase("key_data")

	return ret_dict


## Generate a new uuid for this object.
## Should only be used when the object is supposed to be a new one.
func gen_uuid() -> void:
	uuid = UUID.v4()


## The editor that gets shown when the plugins settings button is pressed.
class KeysEditor:
	extends VBoxContainer

	## Emitted when [param key] is supposed to be added.
	signal key_added(key: SSHKey)
	## Emitted when [param key] is supposed to be deleted.
	signal key_deleted(key: SSHKey)

	var _ssh_keys_list: VBoxContainer = VBoxContainer.new()

	func _init() -> void:
		name = "SSH Keys"

		add_theme_constant_override("separation", 10)
		set_anchors_preset(Control.PRESET_FULL_RECT)

		var header: Label = Label.new()
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.text = "SSH Keys"
		add_child(header)

		_ssh_keys_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(_ssh_keys_list)

		var add_key_button: Button = Button.new()
		add_key_button.text = "Add key"
		add_key_button.pressed.connect(_on_add_key_button_pressed)
		add_child(add_key_button)

	## Set the keys that will be shown in the list.
	func set_keys(keys_list: Array[SSHKey]) -> void:
		for child in _ssh_keys_list.get_children():
			child.queue_free()
		for key in keys_list:
			_add_key(key)

	func _on_key_deleted(key: SSHKey) -> void:
		key_deleted.emit(key)

	func _add_key(key: SSHKey) -> void:
		var key_entry: KeyEntry = KeyEntry.new(key)
		key_entry.key_deleted.connect(_on_key_deleted)
		_ssh_keys_list.add_child(key_entry)

	func _on_add_key_button_pressed() -> void:
		var key_editor: NewSSHKeyEditor = NewSSHKeyEditor.new()
		var callback: Callable = func confirm() -> bool:
			if key_editor.confirm():
				key_added.emit(key_editor.get_key())
				_add_key(key_editor.get_key())
				return true
			return false

		PopupManager.push_stack_item([key_editor], callback)


## An entry in the list of keys in [SSHController.KeysEditor]
class KeyEntry:
	extends PanelContainer

	## Emitted when [param key] is supposed to be deleted.
	signal key_deleted(key: SSHKey)
	## Internal signal to combine a [ConfirmationDialog]'s confirmed and canceled signals.
	signal confirm_dialog_closed(bool)

	const DELETE_ICON = preload("res://resources/icons/trash.svg")

	var _key: SSHKey
	var _edit_button: Button = Button.new()

	func _init(key: SSHKey) -> void:
		key.key_updated.connect(_on_key_updated)
		_key = key

		var stylebox: StyleBoxFlat = StyleBoxFlat.new()
		stylebox.bg_color = Color("#ffffff0c")
		stylebox.corner_radius_bottom_left = 8
		stylebox.corner_radius_bottom_right = 8
		stylebox.corner_radius_top_left = 8
		stylebox.corner_radius_top_right = 8
		stylebox.content_margin_top = 6
		stylebox.content_margin_bottom = 6
		stylebox.content_margin_left = 6
		stylebox.content_margin_right = 6
		add_theme_stylebox_override("panel", stylebox)

		var hbox: HBoxContainer = HBoxContainer.new()

		_edit_button.text = key.name
		_edit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_edit_button.pressed.connect(_on_edit_button_pressed)
		hbox.add_child(_edit_button)

		var delete_button: TextureButton = TextureButton.new()
		delete_button.texture_normal = DELETE_ICON
		delete_button.ignore_texture_size = true
		delete_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		delete_button.custom_minimum_size = Vector2(24, 24)
		delete_button.pressed.connect(_on_delete_button_pressed)
		hbox.add_child(delete_button)

		add_child(hbox)

	func _on_key_updated() -> void:
		_edit_button.text = _key.name

	func _on_edit_button_pressed() -> void:
		var key_editor: ExistingSSHKeyEditor = ExistingSSHKeyEditor.new(_key)
		PopupManager.push_stack_item([key_editor], key_editor.confirm)

	func _on_delete_button_pressed() -> void:
		var confirm_dialog: ConfirmationDialog = ConfirmationDialog.new()
		confirm_dialog.dialog_text = "Do you really want to delete key: %s" % _key.name
		add_child(confirm_dialog)
		confirm_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
		confirm_dialog.show()
		confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
		confirm_dialog.canceled.connect(_on_confirm_dialog_canceled)
		var ret: bool = await confirm_dialog_closed
		confirm_dialog.queue_free()
		if ret:
			key_deleted.emit(_key)
			queue_free()

	func _on_confirm_dialog_confirmed() -> void:
		confirm_dialog_closed.emit(true)

	func _on_confirm_dialog_canceled() -> void:
		confirm_dialog_closed.emit(false)


## Just a common helper class for the special editor.
class SSHKeyEditor:
	extends VBoxContainer

	var _key: SSHKey = null

	func _init(key: SSHKey) -> void:
		_key = key

		set_anchors_preset(Control.PRESET_FULL_RECT)
		add_theme_constant_override("separation", 10)

	## Called on confirm button pressed. Overwrite this.
	func confirm() -> bool:
		return true

	func get_key() -> SSHKey:
		return _key


## Editor that gets shown when an existing key is supposed to be edited.
class ExistingSSHKeyEditor:
	extends SSHKeyEditor

	var _key_editor: Config.ConfigEditor = null

	func _init(key: SSHKey) -> void:
		super(key)

		_key_editor = key.generate_editor()
		add_child(_key_editor)

	## Called on confirm button pressed.
	func confirm() -> bool:
		var abort: bool = false

		var key_dict: Dictionary = _key_editor.serialize()
		if key_dict.name == "":
			_key_editor.get_editor("name").modulate = Color.RED
			abort = true
		if key_dict.type == KeyTypes.EXISTING_KEY and key_dict.key_path == "":
			_key_editor.get_editor("key_path").modulate = Color.RED
			abort = true

		if abort:
			return false

		_key_editor.apply()
		_key.apply_config()

		return true


## Editor that gets shown when an new key is supposed to be added.
class NewSSHKeyEditor:
	extends SSHKeyEditor

	## Possible key sizes for an RSA key.
	const RSA_SIZES: Array[String] = [
		"2048",
		"4096",
		"8192",
		"16384",
	]

	var _key_creator_config: Config = Config.new()
	var _key_creator_editor: Config.ConfigEditor = null
	var _new_key_config: Config = Config.new()
	var _new_key_creator_editor: Config.ConfigEditor = null
	var _import_key_config: Config = Config.new()
	var _import_key_creator_editor: Config.ConfigEditor = null

	func _init() -> void:
		var key: SSHKey = SSHKey.new()
		key.gen_uuid()
		super(key)

		_key_creator_config.add_string("Key name", "name", key.name)
		_key_creator_config.add_dict("Key type", "key_type", key.type, KeyTypes)
		_key_creator_editor = _key_creator_config.generate_editor()

		_key_creator_editor.get_editor("key_type").value_selected.connect(
			_on_key_type_editor_value_selected
		)
		add_child(_key_creator_editor)

		_import_key_config.add_file_path("Key path", "key_path", key.key_path)
		_import_key_creator_editor = _import_key_config.generate_editor()
		_import_key_creator_editor.visible = false
		add_child(_import_key_creator_editor)

		_new_key_config.add_dict("Crypto", "crypto", CryptoTypes.ED25519, CryptoTypes)
		_new_key_config.add_string_array("Key size", "rsa_size", RSA_SIZES[1], RSA_SIZES)
		_new_key_creator_editor = _new_key_config.generate_editor()
		_new_key_creator_editor.get_editor("rsa_size").visible = false
		_new_key_creator_editor.get_editor("crypto").value_selected.connect(
			_on_crypto_value_selected
		)
		add_child(_new_key_creator_editor)

	## Called on confirm button pressed.
	func confirm() -> bool:
		var abort: bool = false

		var new_key_dict: Dictionary = _key_creator_editor.serialize()
		if new_key_dict.name == "":
			_key_creator_editor.get_editor("name").modulate = Color.RED
			abort = true

		var import_key_dict: Dictionary = _import_key_creator_editor.serialize()
		if new_key_dict.key_type == KeyTypes.EXISTING_KEY and import_key_dict.key_path == "":
			_import_key_creator_editor.get_editor("key_path").modulate = Color.RED
			abort = true

		if abort:
			return false

		_key.name = new_key_dict.name

		match new_key_dict.key_type:
			KeyTypes.NEW_KEY:
				var new_key_settings: Dictionary = _new_key_creator_editor.serialize()
				var key_size: int = (
					256
					if new_key_settings.crypto == CryptoTypes.ED25519
					else int(new_key_settings.rsa_size)
				)
				var new_key: String = SSHClient.generate_private_key(
					CryptoTypes.find_key(new_key_settings.crypto),
					key_size,
					"%s@dreamdeck" % new_key_dict.name
				)
				if new_key == "":
					push_error("Failed to generate key")
					return false
				new_key = Marshalls.utf8_to_base64(new_key)
				_key.key_data = new_key
				_key.type = KeyTypes.NEW_KEY
			KeyTypes.EXISTING_KEY:
				_key.key_path = import_key_dict.key_path
				_key.type = KeyTypes.EXISTING_KEY

		return true

	func _on_key_type_editor_value_selected(value_text: String) -> void:
		if not _new_key_creator_editor and not is_instance_valid(_new_key_creator_editor):
			return
		if not _import_key_creator_editor and not is_instance_valid(_import_key_creator_editor):
			return

		_new_key_creator_editor.visible = value_text == "NEW_KEY"
		_import_key_creator_editor.visible = value_text == "EXISTING_KEY"

	func _on_crypto_value_selected(value_text: String) -> void:
		if not _new_key_creator_editor and not is_instance_valid(_new_key_creator_editor):
			return

		var rsa_size_editor: Config.StringArrayEditor = _new_key_creator_editor.get_editor(
			"rsa_size"
		)
		rsa_size_editor.visible = value_text == "RSA"
