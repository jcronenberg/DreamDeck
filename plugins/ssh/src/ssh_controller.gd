class_name SSHController
extends PluginControllerBase

enum ServerCheckMethod {
	NO_CHECK,
	KNOWN_HOSTS,
}

enum KeyTypes {
	NEW_KEY,
	EXISTING_KEY,
}

enum CryptoTypes {
	ED25519,
	RSA,
}

const SETTINGS_PAGE = preload("res://plugins/ssh/src/ssh_config_window.tscn")
const PLUGIN_NAME = "SSH"

## List containing all the currently active clients.
## A client's [Dictionary] contains [code]config[/code] and [code]node[/code].
## TODO move settings page to inner class, make private and update via signals
var _clients_list: Array[Dictionary] = []
var _thread_pool: Array[Thread] = []
var _keys_list: Array[SSHKey] = []
var _keys_editor: KeysEditor
@onready var _keys_conf_path: String = conf_dir.path_join("keys.json")
@onready var _clients_conf_path: String = conf_dir.path_join("clients.json")


func _init() -> void:
	plugin_name = PLUGIN_NAME


func _ready() -> void:
	load_clients()
	load_keys()


func _process(_delta) -> void:
	# Thread cleanup
	for thread in _thread_pool:
		if not thread.is_alive():
			thread.wait_to_finish()
			_thread_pool.erase(thread)


## Adds a key to the keys list and also saves to disk.[br]
## Also updates the keys editor if it is being used
func add_key(new_key: SSHKey) -> void:
	for key in _keys_list:
		if key.key_name == new_key.key_name:
			push_error("Key with the same name already exists")
			return

	_keys_list.append(new_key)
	if _keys_editor and is_instance_valid(_keys_editor):
		_keys_editor.set_keys(_keys_list)

	save_keys()


## Removes a key from the keys list and saves to disk.
func remove_key(key: SSHKey) -> void:
	_keys_list.erase(key)
	save_keys()


## Loads keys from disk.
func load_keys() -> void:
	var loaded_keys_config: Variant = ConfLib.load_config(_keys_conf_path)
	if loaded_keys_config is not Array:
		return

	_keys_list = []
	for key_dict in loaded_keys_config:
		var new_key: SSHKey = SSHKey.new()
		new_key.deserialize(key_dict)
		add_key(new_key)


## Saves keys to disk.
func save_keys() -> void:
	var keys: Array[Dictionary] = []
	for key in _keys_list:
		keys.append(key.serialize())

	ConfLib.save_config(_keys_conf_path, keys)


## Generates a [Config] with all default objects configured.
func generate_default_client_config() -> Config:
	var client_config: Config = Config.new()
	client_config.add_string("Name", "name", "")
	client_config.add_string("Server ip address", "ip", "")
	client_config.add_int("Server port", "port", 22)
	client_config.add_string("Username", "user", "")
	client_config.add_file_path("Secret key path", "key_path", "")
	client_config.add_enum(
		"Server check method",
		"server_check_method",
		ServerCheckMethod.KNOWN_HOSTS,
		ServerCheckMethod,
		"Whether the server should be checked against the known hosts"
	)
	client_config.add_bool("Debug", "debug", false)
	return client_config


## Loads clients from disk.
func load_clients() -> void:
	var loaded_clients_config: Variant = ConfLib.load_config(_clients_conf_path)
	if loaded_clients_config is not Array:
		return

	_clients_list = []
	for client_dict in loaded_clients_config:
		var new_client: Config = generate_default_client_config()
		new_client.apply_dict(client_dict)
		add_client(new_client)


## Saves clients to disk.
func save_clients() -> void:
	var serialized_clients_list: Array[Dictionary] = []
	for client in _clients_list:
		serialized_clients_list.append(client.config.get_as_dict())
		ConfLib.save_config(_clients_conf_path, serialized_clients_list)


## Adds a new client with the [param client_config].
func add_client(client_config: Config) -> void:
	var ssh_client: SSHClient = SSHClient.new()

	var client_dict: Dictionary = {"config": client_config, "node": ssh_client}
	_clients_list.push_back(client_dict)
	edit_client_config(_clients_list.size() - 1)
	update_loader_clients_list()


## Updates the action in the loader so it always shows all available clients.
func update_loader_clients_list() -> void:
	var clients: Array[String] = []
	for client in _clients_list:
		clients.append(client.config.get_object("name").get_value())
	PluginCoordinator.get_plugin_loader("SSH").set_client_config(clients)


## Edits a client in both the child SSHClient node and [member _clients_list].
## The config needs to be edited beforehand by the caller.
func edit_client_config(index: int) -> void:
	assert(_clients_list.size() > index)

	var client_dict: Dictionary = _clients_list[index]
	if not client_dict:
		push_error("SSHClient not found")
		return

	var client_config: Dictionary = client_dict.config.get_as_dict()
	client_dict.node.disconnect_session()
	client_dict.node.user = client_config.user
	client_dict.node.ip = client_config.ip
	client_dict.node.port = client_config.port
	client_dict.node.set_auth_key_file(client_config["key_path"], "")
	match client_config["server_check_method"]:
		ServerCheckMethod.NO_CHECK:
			client_dict.node.set_server_check_method("no_check")
		ServerCheckMethod.KNOWN_HOSTS:
			client_dict.node.set_server_check_method("known_hosts_file")
		_:
			push_error("Unknown server check method, setting to known hosts file")
			client_dict.node.set_server_check_method("known_hosts_file")
	client_dict.node.set_debug(client_config.debug)
	var error: Variant = client_dict.node.open_session()
	if error:
		push_error('Failed to open session for client "%s": %s' % [client_config["name"], error])

	save_clients()


## Get a SSH client identified by [param client_name]
func get_client(client_name: String) -> SSHClient:
	for client in _clients_list:
		if client_name == client.config.get_object("name").get_value():
			return client.node

	return null


## Removes a SSH client identified by [param client_name]
## from both the client list and the [SSHClient] child.
func remove_client(client_name: String) -> void:
	for client in _clients_list:
		if client.config.get_object("name").get_value() == client_name:
			client.node.queue_free()
			_clients_list.erase(client)


# maybe switch away from identifier client_name to index, but having the same name is
# still confusing so having unique names should probably still be enforced
## Executes the [param cmd] string on client, which is identified by [param client_name].
## This operation is done asynchronously to not block the main thread.
func exec_on_client(client_name: String, cmd: String) -> void:
	var ssh_client: SSHClient = get_client(client_name)
	if not ssh_client:
		push_error("Couldn't execute %s: SSHClient %s not found" % [cmd, client_name])
		return

	var thread: Thread = Thread.new()
	thread.start(ssh_client.exec.bind(cmd))
	_thread_pool.append(thread)


func _on_settings_button_pressed() -> void:
	var clients_editor: Control = SETTINGS_PAGE.instantiate()
	clients_editor.name = "SSH Clients"

	if _keys_editor and is_instance_valid(_keys_editor):
		_keys_editor.queue_free()
	_keys_editor = KeysEditor.new()
	_keys_editor.set_keys(_keys_list)
	_keys_editor.key_changed.connect(save_keys)
	_keys_editor.key_changed.connect(_keys_editor.set_keys.bind(_keys_list))
	_keys_editor.key_added.connect(add_key)
	_keys_editor.key_deleted.connect(remove_key)

	PopupManager.push_stack_item([clients_editor, _keys_editor])


## Stores an SSH key.
class SSHKey:
	## Name of the key, must be unique as it is the identifier.
	var key_name: String = ""
	## Type of the key.
	var type: KeyTypes = KeyTypes.NEW_KEY
	## Data of the private key when [member type] is [code]NEW_KEY[/code].
	var key_data: String = ""
	## Path to the private key when [member type] is [code]EXISTING_KEY[/code]
	var key_path: String = ""

	## Fill values from [param dict].
	func deserialize(dict: Dictionary) -> void:
		for key in dict:
			if not key in self:
				continue
			set(key, dict[key])

		if key_data != "":
			type = KeyTypes.NEW_KEY
		elif key_path != "":
			type = KeyTypes.EXISTING_KEY

	## Create a [Dictionary] with appropriate values.
	## Note: Depending on the [member type],
	## only either [member key_data] or [member key_path] will be saved.
	## Will also emit an error when both are set, as this is not intended behaviour.
	func serialize() -> Dictionary:
		var ret_dict: Dictionary = {"key_name": key_name}
		if key_data != "":
			ret_dict.key_data = key_data
		elif key_path != "":
			ret_dict.key_path = key_path
		else:
			push_error("SSHKey is configured wrong")

		return ret_dict


## The editor that gets shown when the plugins settings button is pressed.
class KeysEditor:
	extends VBoxContainer

	## Emitted when a key was edited.
	signal key_changed
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
		var key_names_list: Array[String] = []
		for key in keys_list:
			key_names_list.append(key.key_name)

		for child in _ssh_keys_list.get_children():
			child.queue_free()
		for key in keys_list:
			var key_entry: KeyEntry = KeyEntry.new(key)
			key_entry.key_names_list = key_names_list
			key_entry.key_deleted.connect(_on_key_deleted)
			key_entry.key_changed.connect(key_changed.emit)
			_ssh_keys_list.add_child(key_entry)

	func _on_key_deleted(key: SSHKey) -> void:
		key_deleted.emit(key)

	func _on_add_key_button_pressed() -> void:
		var new_key: SSHKey = SSHKey.new()
		var key_editor: NewSSHKeyEditor = NewSSHKeyEditor.new(new_key)
		key_editor.set_key_names_list(_generate_key_names_list())
		var callback: Callable = func confirm() -> bool:
			if key_editor.confirm():
				key_added.emit(new_key)
				return true
			return false

		PopupManager.push_stack_item([key_editor], callback)

	func _generate_key_names_list() -> Array[String]:
		var ret: Array[String] = []
		for entry: KeyEntry in _ssh_keys_list.get_children():
			ret.append(entry._key.key_name)

		return ret


## An entry in the list of keys in [SSHController.KeysEditor]
class KeyEntry:
	extends PanelContainer

	## Emitted when the key was edited.
	signal key_changed
	## Emitted when [param key] is supposed to be deleted.
	signal key_deleted(key: SSHKey)
	## Internal signal to combine a [ConfirmationDialog]'s confirmed and canceled signals.
	signal confirm_dialog_closed(bool)

	const DELETE_ICON = preload("res://resources/icons/trash.svg")

	## List of all key names to check if the key's [member SSHController.SSHKey.key_name] is unique.
	var key_names_list: Array[String]

	var _key: SSHKey
	var _edit_button: Button = Button.new()

	func _init(key: SSHKey) -> void:
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

		_edit_button.text = key.key_name
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

	func _on_edit_button_pressed() -> void:
		var key_editor: ExistingSSHKeyEditor = ExistingSSHKeyEditor.new(_key)
		key_editor.set_key_names_list(key_names_list)
		var callback: Callable = func confirm() -> bool:
			if key_editor.confirm():
				# _edit_button.text = _key.key_name
				key_changed.emit()
				return true
			return false

		PopupManager.push_stack_item([key_editor], callback)

	func _on_delete_button_pressed() -> void:
		var confirm_dialog: ConfirmationDialog = ConfirmationDialog.new()
		confirm_dialog.dialog_text = "Do you really want to delete key: %s" % _key.key_name
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

	## List of all key names to check if the key's [member SSHController.SSHKey.key_name] is unique.
	var key_names_list: Array[String] = []:
		set = set_key_names_list

	var _key: SSHKey = null

	func _init(key: SSHKey) -> void:
		_key = key

		set_anchors_preset(Control.PRESET_FULL_RECT)
		add_theme_constant_override("separation", 10)

	## Sets [member key_names_list] but removes the set key's [member SSHKey.key_name].
	func set_key_names_list(value: Array[String]) -> void:
		key_names_list = value
		if _key:
			key_names_list.erase(_key.key_name)

	## Called on confirm button pressed. Overwrite this.
	func confirm() -> bool:
		return true

	func _check_unique_key(key_name: String) -> bool:
		return not key_name in key_names_list


## Editor that gets shown when an existing key is supposed to be edited.
class ExistingSSHKeyEditor:
	extends SSHKeyEditor

	var _key_config: Config = Config.new()
	var _key_editor: Config.ConfigEditor = null

	func _init(key: SSHKey) -> void:
		super(key)

		_key_config.add_string("Key name", "key_name", key.key_name)
		if key.type == KeyTypes.EXISTING_KEY:
			_key_config.add_file_path("Key path", "key_path", key.key_path)
		_key_editor = _key_config.generate_editor()
		add_child(_key_editor)

	## Called on confirm button pressed.
	func confirm() -> bool:
		var abort: bool = false

		var key_dict: Dictionary = _key_editor.serialize()
		if key_dict.key_name == "" or not _check_unique_key(key_dict.key_name):
			_key_editor.get_editor("key_name").modulate = Color.RED
			abort = true
		if key_dict.has("key_path") and key_dict.key_path == "":
			_key_editor.get_editor("key_path").modulate = Color.RED
			abort = true

		if abort:
			return false

		_key.key_name = key_dict.key_name
		if key_dict.has("key_path"):
			_key.key_path = key_dict.key_path

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

	func _init(key: SSHKey) -> void:
		super(key)

		_key_creator_config.add_string("Key name", "key_name", key.key_name)
		_key_creator_config.add_enum("Key type", "key_type", key.type, KeyTypes)
		_key_creator_editor = _key_creator_config.generate_editor()

		_key_creator_editor.get_editor("key_type").value_selected.connect(
			_on_key_type_editor_value_selected
		)
		add_child(_key_creator_editor)

		_import_key_config.add_file_path("Key path", "key_path", key.key_path)
		_import_key_creator_editor = _import_key_config.generate_editor()
		_import_key_creator_editor.visible = false
		add_child(_import_key_creator_editor)

		_new_key_config.add_enum("Crypto", "crypto", CryptoTypes.ED25519, CryptoTypes)
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
		if new_key_dict.key_name == "" or not _check_unique_key(new_key_dict.key_name):
			_key_creator_editor.get_editor("key_name").modulate = Color.RED
			abort = true

		var import_key_dict: Dictionary = _import_key_creator_editor.serialize()
		if new_key_dict.key_type == KeyTypes.EXISTING_KEY and import_key_dict.key_path == "":
			_import_key_creator_editor.get_editor("key_path").modulate = Color.RED
			abort = true

		if abort:
			return false

		_key.key_name = new_key_dict.key_name

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
					"%s@dreamdeck" % new_key_dict.key_name
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
