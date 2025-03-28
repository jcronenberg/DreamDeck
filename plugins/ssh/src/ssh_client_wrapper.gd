class_name SSHClientWrapper

## Emitted when the client config was updated.
## Note: not emitted on [method deserialize].
signal client_updated

## All available methods to check the server against.
## [code]KNOWN_HOSTS[/code] uses the default known hosts file.
enum ServerCheckMethod {
	NO_CHECK,
	KNOWN_HOSTS,
}

## User facing name of the client.
var name: String:
	set(value):
		name = value
		_config.get_object("name").set_value(value)
## UUID to id the client by.
## Used because the name may change.
var uuid: String:
	set(value):
		uuid = value
		_config.get_object("uuid").set_value(value)
## SSH user.
var user: Variant:
	get:
		return _client.user
	set(value):
		_client.user = value
		_config.get_object("user").set_value(user)
## SSH server ip.
var ip: Variant:
	get:
		return _client.ip
	set(value):
		_client.ip = value
		_config.get_object("ip").set_value(value)
## SSH port.
var port: int:
	get:
		return _client.port
	set(value):
		_client.port = value
		_config.get_object("port").set_value(value)
## Debug state.
var debug: bool:
	get:
		return _client.get_debug()
	set(value):
		_client.set_debug(value)
		_config.get_object("debug").set_value(value)
## The [SSHKey]'s uuid.
var key_uuid: String:
	get:
		return _key.uuid
	set(value):
		var key: SSHKey = (
			PluginCoordinator
			. get_plugin_loader("SSH")
			. get_controller("SSHController")
			. get_key(value)
		)
		if key:
			_key = key
			_config.get_object("key_uuid").set_value(value)
		else:
			push_error("Failed to get ssh key with uuid: %s" % value)

# Internal [SSHKey], use [member key_uuid] to set this.
var _key: SSHKey:
	set(value):
		if _key:
			_key.key_updated.disconnect(apply_key_to_client)
		value.key_updated.connect(apply_key_to_client)
		_key = value
		if _client:
			apply_key_to_client()
# Internal [SSHClient].
var _client: SSHClient = SSHClient.new()
# Internal config.
var _config: Config = _generate_default_client_config()


## Only use this to call functions on the client.
## To configure the client, use the properties of this wrapper.
func get_client() -> SSHClient:
	return _client


## Generate a [Config.ConfigEditor] with all the relevant config options.
func generate_editor() -> Config.ConfigEditor:
	var editor: Config.ConfigEditor = _config.generate_editor()
	# Hide uuid editor, as this is never supposed to be edited.
	editor.get_editor("uuid").visible = false
	return editor


## Apply the current config to the object.
## This is supposed to be called after the editor was edited.
func apply_config() -> void:
	var dict: Dictionary = _config.get_as_dict()
	deserialize(dict)
	client_updated.emit()


## Serialize to a [Dictionary] for saving.
func serialize() -> Dictionary:
	return _config.get_as_dict()


## Deserialize the object from a [param dict].
func deserialize(dict: Dictionary) -> void:
	name = dict.name
	user = dict.user
	ip = dict.ip
	port = dict.port
	debug = dict.debug
	uuid = dict.uuid
	if dict.has("key_uuid") and dict.key_uuid:
		key_uuid = dict.key_uuid
	match dict.server_check_method as int:
		ServerCheckMethod.NO_CHECK:
			_client.set_server_check_method("no_check")
		ServerCheckMethod.KNOWN_HOSTS:
			_client.set_server_check_method("known_hosts_file")
		_:
			push_error("Unknown server check method, setting to known hosts file")
			_client.set_server_check_method("known_hosts_file")


## Generate a new uuid for this object.
## Should only be used when the object is supposed to be a new one.
func gen_uuid() -> void:
	uuid = UUID.v4()


## Update the available keys dictionary.
func update_keys(keys_dict: Dictionary) -> void:
	_config.get_object("key_uuid").set_dict(keys_dict)


## Applies the currently set key to the internal ssh client.
func apply_key_to_client() -> void:
	match _key.type:
		SSHKey.KeyTypes.NEW_KEY:
			_client.set_auth_key(Marshalls.base64_to_utf8(_key.key_data), "")
		SSHKey.KeyTypes.EXISTING_KEY:
			_client.set_auth_key_file(_key.key_path, "")


# Generates a [Config] with all default objects configured.
func _generate_default_client_config() -> Config:
	var client_config: Config = Config.new()
	client_config.add_string("UUID", "uuid", "")
	client_config.add_string("Name", "name", "")
	client_config.add_string("Server domain or ip", "ip", "")
	client_config.add_int("Server port", "port", 22)
	client_config.add_string("Username", "user", "")
	client_config.add_dict("SSH Key", "key_uuid", null, {})
	client_config.add_dict(
		"Server check method",
		"server_check_method",
		ServerCheckMethod.KNOWN_HOSTS,
		ServerCheckMethod,
		"Whether the server should be checked against the known hosts"
	)
	client_config.add_bool("Debug", "debug", false)
	return client_config


class SSHClientsEditor:
	extends VBoxContainer

	## Emitted when [param key] is supposed to be added.
	signal client_added(client: SSHClientWrapper)
	## Emitted when [param key] is supposed to be deleted.
	signal client_deleted(client: SSHClientWrapper)

	const SSH_THEME = preload("res://plugins/ssh/assets/ssh_theme.tres")

	var _client_entries: VBoxContainer = VBoxContainer.new()

	func _init() -> void:
		name = "SSH Clients"
		theme = SSH_THEME

		add_theme_constant_override("separation", 10)
		set_anchors_preset(Control.PRESET_FULL_RECT)

		var header: Label = Label.new()
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.text = "SSH Clients"
		add_child(header)

		_client_entries.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(_client_entries)

		var add_client_button: Button = Button.new()
		add_client_button.text = "Add client"
		add_client_button.pressed.connect(_on_add_client_button_pressed)
		add_child(add_client_button)

	func set_clients(clients: Array[SSHClientWrapper]) -> void:
		for client_entry in _client_entries.get_children():
			client_entry.queue_free()

		for client in clients:
			_add_client(client)

	func _add_client(client: SSHClientWrapper) -> void:
		var client_entry: ClientEntry = ClientEntry.new(client)
		client_entry.client_deleted.connect(client_deleted.emit)
		_client_entries.add_child(client_entry)

	func _on_add_client_button_pressed() -> void:
		var client_editor: ClientEditor = ClientEditor.new(null)
		var callback: Callable = func confirm() -> bool:
			if client_editor.confirm():
				client_added.emit(client_editor.get_client())
				_add_client(client_editor.get_client())
				return true
			return false

		PopupManager.push_stack_item([client_editor], callback)


class ClientEntry:
	extends PanelContainer

	## Emitted when [param key] is supposed to be deleted.
	signal client_deleted(client: SSHClientWrapper)
	## Internal signal to combine a [ConfirmationDialog]'s confirmed and canceled signals.
	signal confirm_dialog_closed(bool)

	const DELETE_ICON = preload("res://resources/icons/trash.svg")

	var _client: SSHClientWrapper
	var _edit_button: Button = Button.new()

	func _init(client: SSHClientWrapper) -> void:
		client.client_updated.connect(_on_client_updated)
		_client = client

		theme_type_variation = "SettingsList"

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 0)

		_edit_button.text = client.name
		_edit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_edit_button.pressed.connect(_on_edit_button_pressed)
		_edit_button.theme_type_variation = "ListButton"
		hbox.add_child(_edit_button)

		var delete_button: Button = Button.new()
		delete_button.icon = DELETE_ICON
		delete_button.theme_type_variation = "ListDeleteButton"
		delete_button.pressed.connect(_on_delete_button_pressed)
		hbox.add_child(delete_button)

		add_child(hbox)

	func _on_client_updated() -> void:
		_edit_button.text = _client.name

	func _on_edit_button_pressed() -> void:
		var client_editor: ClientEditor = ClientEditor.new(_client)
		PopupManager.push_stack_item([client_editor], client_editor.confirm)

	func _on_delete_button_pressed() -> void:
		var confirm_dialog: ConfirmationDialog = ConfirmationDialog.new()
		confirm_dialog.dialog_text = "Do you really want to delete client: %s" % _client.name
		add_child(confirm_dialog)
		confirm_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
		confirm_dialog.show()
		confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
		confirm_dialog.canceled.connect(_on_confirm_dialog_canceled)
		var ret: bool = await confirm_dialog_closed
		confirm_dialog.queue_free()
		if ret:
			client_deleted.emit(_client)
			queue_free()

	func _on_confirm_dialog_confirmed() -> void:
		confirm_dialog_closed.emit(true)

	func _on_confirm_dialog_canceled() -> void:
		confirm_dialog_closed.emit(false)


class ClientEditor:
	extends VBoxContainer

	var _client: SSHClientWrapper
	var _client_editor: Config.ConfigEditor = null

	func _init(client: SSHClientWrapper) -> void:
		if not client:
			_client = SSHClientWrapper.new()
			_client.gen_uuid()
			_client.update_keys(
				(
					PluginCoordinator
					. get_plugin_loader("SSH")
					. get_controller("SSHController")
					. get_keys_dict()
				)
			)
		else:
			_client = client

		_client_editor = _client.generate_editor()

		set_anchors_preset(Control.PRESET_FULL_RECT)
		add_theme_constant_override("separation", 10)

		add_child(_client_editor)

	## Called on confirm button pressed.
	func confirm() -> bool:
		var abort: bool = false
		abort = not _client_editor.get_editor("name").validate("") or abort
		abort = not _client_editor.get_editor("ip").validate("") or abort
		abort = not _client_editor.get_editor("user").validate("") or abort
		if abort:
			return false

		_client_editor.apply()
		_client.apply_config()

		return true

	func get_client() -> SSHClientWrapper:
		return _client
