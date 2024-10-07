class_name SSHController
extends PluginControllerBase

const PLUGIN_NAME = "SSH"
const EMPTY_CLIENT = {
	"name": "",
	"ip": "",
	"user": "",
	"port": 22,
	"key_path": "",
	}

@onready var conf_path = conf_dir + "clients.json"

var client_list: Array = []
var thread_pool: Array


func _init():
	plugin_name = PLUGIN_NAME


func _ready():
	load_client_config()

	# FIXME config label migration, delete in the future
	GlobalSignals.connect("exited_edit_mode", _on_exited_edit_mode)


func _process(_delta):
	# Thread cleanup
	for thread in thread_pool:
		if not thread.is_alive():
			thread.wait_to_finish()
			thread_pool.erase(thread)


func load_client_config():
	var loaded_client_config: Variant = ConfLib.load_config(conf_path)
	var client_config: Array

	# FIXME delete in the future, migration from old config style
	if loaded_client_config is Dictionary:
		client_config = loaded_client_config["ssh_clients"]
	elif loaded_client_config is Array:
		client_config = loaded_client_config

	for client in client_config:
		add_client(client)


func new_client(client_name: String, ip: String, user: String, port: int, key_path: String):
	var client_dict = {
		"name": client_name,
		"ip": ip,
		"user": user,
		"port": port,
		"key_path": key_path,
		}
	client_list.push_back(client_dict)
	save_config()
	add_client(client_dict)


func save_config():
	ConfLib.save_config(conf_path, client_list)


func add_new_client(client_dict: Dictionary):
	client_list.push_back(client_dict)
	add_client(client_dict)


## [param client_dict] should contain: TODO
func add_client(client_dict: Dictionary):
	var ssh_client = SSHClient.new()
	ssh_client.name = client_dict["name"]
	add_child(ssh_client)
	edit_client_config(get_child_count() - 1, client_dict)
	update_loader_client_list()


## Updates the action in the loader so it always shows all available clients
func update_loader_client_list() -> void:
	var clients: Array[String] = []
	for client in client_list:
		clients.append(client["name"])
	PluginCoordinator.get_plugin_loader("SSH").set_client_config(clients)


## Edits a client in both the child SSHClient node and [member client_list].
func edit_client_config(index: int, client_dict: Dictionary):
	var ssh_client = get_child(index)
	if not ssh_client:
		push_error("SSHClient not found")
		return
	ssh_client.disconnect_session()
	ssh_client.setup(client_dict["user"], client_dict["ip"], int(client_dict["port"]))
	ssh_client.set_auth_method("key_file", client_dict["key_path"], "")
	ssh_client.set_server_check_method("known_hosts_file")
	# TODO change with config
	ssh_client.set_debug(true)
	ssh_client.open_session()

	if client_list.size() <= index:
		client_list.push_back(client_dict)
	else:
		client_list[index] = client_dict
	save_config()


func get_client_list() -> Array:
	return client_list


func get_client(client_name: String):
	for client_id in client_list.size():
		if client_name == client_list[client_id]["name"]:
			return get_child(client_id)


# maybe switch away from identifier client_name to index, but having the same name is
# still confusing so having unique names should probably still be enforced
func exec_on_client(client_name: String, cmd: String):
	var ssh_client = get_client(client_name)
	if not ssh_client:
		push_error("Couldn't execute %s: SSHClient %s not found" % [cmd, client_name])
		return

	var thread := Thread.new()
	thread.start(ssh_client.exec.bind(cmd))
	thread_pool.append(thread)


func _on_exited_edit_mode() -> void:
	config.save()
