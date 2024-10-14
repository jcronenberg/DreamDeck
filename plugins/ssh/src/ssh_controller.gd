class_name SSHController
extends PluginControllerBase

const PLUGIN_NAME = "SSH"

## List containing all the currently active client [Config]s.
var client_list: Array[Config] = []

@onready var _conf_path: String = conf_dir + "clients.json"
var _thread_pool: Array[Thread] = []


func _init() -> void:
	plugin_name = PLUGIN_NAME


func _ready() -> void:
	load_clients()


func _process(_delta) -> void:
	# Thread cleanup
	for thread in _thread_pool:
		if not thread.is_alive():
			thread.wait_to_finish()
			_thread_pool.erase(thread)


## Generates a [Config] with all default objects configured.
func generate_default_client_config() -> Config:
	var client_config: Config = Config.new()
	client_config.add_string("Name", "name", "")
	client_config.add_string("Server ip address", "ip", "")
	client_config.add_int("Server port", "port", 22)
	client_config.add_string("Username", "user", "")
	client_config.add_file_path("Secret key path", "key_path", "")
	client_config.add_bool("Debug", "debug", false)
	return client_config


## Loads clients from disk.
func load_clients() -> void:
	var loaded_client_config: Variant = ConfLib.load_config(_conf_path)
	if loaded_client_config is not Array:
		return

	client_list = []
	for client_dict in loaded_client_config:
		var new_client: Config = generate_default_client_config()
		new_client.apply_dict(client_dict)
		add_client(new_client)


## Saves clients to disk.
func save_clients() -> void:
	var serialized_client_list: Array[Dictionary] = []
	for client_config in client_list:
		serialized_client_list.append(client_config.get_as_dict())
		ConfLib.save_config(_conf_path, serialized_client_list)


## Adds a new client with the [param client_config].
func add_client(client_config: Config) -> void:
	client_list.push_back(client_config)

	var ssh_client: SSHClient = SSHClient.new()
	var client_dict: Dictionary = client_config.get_as_dict()
	ssh_client.name = client_dict["name"]
	add_child(ssh_client)
	edit_client_config(get_child_count() - 1)
	update_loader_client_list()


## Updates the action in the loader so it always shows all available clients.
func update_loader_client_list() -> void:
	var clients: Array[String] = []
	for client in client_list:
		clients.append(client.get_object("name").get_value())
	PluginCoordinator.get_plugin_loader("SSH").set_client_config(clients)


## Edits a client in both the child SSHClient node and [member client_list].
## The config needs to be edited beforehand by the caller.
func edit_client_config(index: int) -> void:
	assert(client_list.size() > index)

	var ssh_client: SSHClient = get_child(index)
	if not ssh_client:
		push_error("SSHClient not found")
		return

	var client_dict: Dictionary = client_list[index].get_as_dict()
	ssh_client.disconnect_session()
	ssh_client.setup(client_dict["user"], client_dict["ip"], int(client_dict["port"]))
	ssh_client.set_auth_method("key_file", client_dict["key_path"], "")
	ssh_client.set_server_check_method("known_hosts_file")
	ssh_client.set_debug(client_dict["debug"])
	ssh_client.open_session()

	save_clients()


## Get a SSH client identified by [param client_name]
func get_client(client_name: String) -> SSHClient:
	for client_id in client_list.size():
		if client_name == client_list[client_id].get_object("name").get_value():
			return get_child(client_id)

	return null


## Removes a SSH client identified by [param client_name]
## from both the client list and the [SSHClient] child.
func remove_client(client_name: String) -> void:
	var ssh_client: SSHClient = get_client(client_name)
	if ssh_client:
		ssh_client.queue_free()

	for client_config in client_list:
		if client_config.get_object("name").get_value() == client_name:
			client_list.erase(client_config)


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
