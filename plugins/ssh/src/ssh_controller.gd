class_name SSHController
extends PluginControllerBase

const PLUGIN_NAME = "SSH"

var _thread_pool: Array[Thread] = []
var _clients: Array[SSHClientWrapper] = []
var _keys: Array[SSHKey] = []
@onready var _keys_conf_path: String = conf_dir.path_join("keys.json")
@onready var _clients_conf_path: String = conf_dir.path_join("clients.json")


func _init() -> void:
	plugin_name = PLUGIN_NAME


func _ready() -> void:
	load_keys()
	load_clients()


func _process(_delta) -> void:
	# Thread cleanup
	for thread in _thread_pool:
		if not thread.is_alive():
			thread.wait_to_finish()
			_thread_pool.erase(thread)


## Adds a key to the keys list and also saves to disk.[br]
## Also updates the keys editor if it is being used
func add_key(new_key: SSHKey) -> void:
	new_key.key_updated.connect(save_keys)
	_keys.append(new_key)

	save_keys()


## Removes a key from the keys list and saves to disk.
func remove_key(key: SSHKey) -> void:
	_keys.erase(key)
	save_keys()


func get_key(key_uuid: String) -> SSHKey:
	for key in _keys:
		if key.uuid == key_uuid:
			return key

	return null


func get_keys_dict() -> Dictionary:
	var dict: Dictionary = {}
	for key in _keys:
		if not dict.has(key.name):
			dict[key.name] = key.uuid
			continue

		# If dict already contains the keys name, append a (2..) behind it
		var key_name: String = key.name
		var i: int = 2
		while dict.has(key_name):
			key_name = "%s (%s)" % [key.name, str(i)]
			i += 1

		dict[key_name] = key.uuid

	return dict


## Loads keys from disk.
func load_keys() -> void:
	var loaded_keys_config: Variant = ConfLib.load_config(_keys_conf_path)
	if loaded_keys_config is not Array:
		return

	_keys = []
	for key_dict in loaded_keys_config:
		var new_key: SSHKey = SSHKey.new()
		new_key.deserialize(key_dict)
		new_key.key_updated.connect(save_keys)
		_keys.append(new_key)


## Saves keys to disk.
func save_keys() -> void:
	var keys: Array[Dictionary] = []
	for key in _keys:
		keys.append(key.serialize())

	ConfLib.save_config(_keys_conf_path, keys)
	update_clients_keys()


## Loads clients from disk.
func load_clients() -> void:
	var loaded_clients_config: Variant = ConfLib.load_config(_clients_conf_path)
	if loaded_clients_config is not Array:
		return

	_clients = []
	for client_dict in loaded_clients_config:
		var new_client: SSHClientWrapper = SSHClientWrapper.new()
		new_client.update_keys(get_keys_dict())
		new_client.client_updated.connect(save_clients)
		new_client.deserialize(client_dict)
		_clients.append(new_client)

	update_loader_clients()


## Saves clients to disk.
func save_clients() -> void:
	var serialized_clients: Array[Dictionary] = []
	for client in _clients:
		serialized_clients.append(client.serialize())
		ConfLib.save_config(_clients_conf_path, serialized_clients)


## Adds a new client with the [param client_config].
func add_client(client: SSHClientWrapper) -> void:
	_clients.append(client)
	client.client_updated.connect(save_clients)
	update_loader_clients()
	save_clients()


## Updates the action in the loader so it always shows all available clients.
func update_loader_clients() -> void:
	var clients: Dictionary = {}
	for client in _clients:
		if not clients.has(client.name):
			clients[client.name] = client.uuid
			continue

		# If dict already contains the client_name, append a (2..) behind it
		var client_name: String = client.name
		var i: int = 2
		while clients.has(client_name):
			client_name = "%s (%s)" % [client.name, str(i)]
			i += 1

		clients[client_name] = client.uuid

	PluginCoordinator.get_plugin_loader("SSH").set_client_config(clients)


func update_clients_keys() -> void:
	for client in _clients:
		client.update_keys(get_keys_dict())


## Get a SSH client identified by [param client_uuid]
## Can also be the client name, though this functionality will be deleted in the future.
func get_client(client_uuid: String) -> SSHClientWrapper:
	for client in _clients:
		if client.uuid == client_uuid:
			return client
		if client.name == client_uuid:
			return client

	return null


## Removes a SSH client identified by [param client_uuid].
func remove_client(client: SSHClientWrapper) -> void:
	_clients.erase(client)
	save_clients()


## Executes the [param cmd] string on client, which is identified by [param client_uuid].
## This operation is done asynchronously to not block the main thread.
func exec_on_client(blocking: bool, client_uuid: String, cmd: String) -> bool:
	var ssh_client: SSHClientWrapper = get_client(client_uuid)
	if not ssh_client:
		push_error("Couldn't execute %s: SSHClient %s not found" % [cmd, client_uuid])
		return false

	if blocking:
		var output: Variant = ssh_client.exec_blocking(cmd)
		if not output:
			return false

		return output.exit_status != -1

	# Even though we are in non blocking mode and exec() is non blocking
	# it isn't actually non blocking, it just doesn't block when the execution has started
	# until then it does block, so to avoid any delay it is still moved to a different thread.
	var thread: Thread = Thread.new()
	thread.start(ssh_client.get_client().exec.bind(cmd))
	_thread_pool.append(thread)

	return true


func _on_settings_button_pressed() -> void:
	var clients_editor: SSHClientWrapper.SSHClientsEditor = SSHClientWrapper.SSHClientsEditor.new()
	clients_editor.set_clients(_clients)
	clients_editor.client_added.connect(add_client)
	clients_editor.client_deleted.connect(remove_client)

	var keys_editor: SSHKey.KeysEditor = SSHKey.KeysEditor.new()
	keys_editor.set_keys(_keys)
	keys_editor.key_added.connect(add_key)
	keys_editor.key_deleted.connect(remove_key)

	PopupManager.push_stack_item([clients_editor, keys_editor])
