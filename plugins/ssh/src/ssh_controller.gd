class_name SSHController
extends PluginControllerBase

enum ServerCheckMethod {
	NO_CHECK,
	KNOWN_HOSTS,
}

const SETTINGS_PAGE = preload("res://plugins/ssh/src/ssh_config_window.tscn")
const PLUGIN_NAME = "SSH"

## List containing all the currently active clients.
## A client's [Dictionary] contains [code]config[/code] and [code]node[/code].
## TODO move settings page to inner class, make private and update via signals
var _clients_list: Array[Dictionary] = []
var _thread_pool: Array[Thread] = []
var _keys_list: Array[SSHKey] = []
var _keys_editor: SSHKey.KeysEditor
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
func exec_on_client(blocking: bool, client_name: String, cmd: String) -> bool:
	var ssh_client: SSHClient = get_client(client_name)
	if not ssh_client:
		push_error("Couldn't execute %s: SSHClient %s not found" % [cmd, client_name])
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
	thread.start(ssh_client.exec.bind(cmd))
	_thread_pool.append(thread)

	return true


func _on_settings_button_pressed() -> void:
	var clients_editor: Control = SETTINGS_PAGE.instantiate()
	clients_editor.name = "SSH Clients"

	if _keys_editor and is_instance_valid(_keys_editor):
		_keys_editor.queue_free()
	_keys_editor = SSHKey.KeysEditor.new()
	_keys_editor.set_keys(_keys_list)
	_keys_editor.key_changed.connect(save_keys)
	_keys_editor.key_changed.connect(_keys_editor.set_keys.bind(_keys_list))
	_keys_editor.key_added.connect(add_key)
	_keys_editor.key_deleted.connect(remove_key)

	PopupManager.push_stack_item([clients_editor, _keys_editor])
