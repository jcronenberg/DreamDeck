extends Node
# TODO add a way to delete SSHClients

class_name SSHController

const PLUGIN_NAME = "SSH"
const EMPTY_CLIENT = {
	"name": "",
	"ip": "",
	"user": "",
	"port": 22,
	"key_path": "",
	}

var client_list := []

var thread_pool: Array
var main_menu_button = null
var config_window_scene = null

@onready var plugin_loader := get_node("/root/PluginLoader")
@onready var conf_dir = plugin_loader.get_conf_dir(PLUGIN_NAME)
@onready var client_config = load("res://scripts/global/Config.gd").new({"ssh_clients": []}, conf_dir + "clients.json")
@onready var execute_function_button := load("res://scenes/MainMenu/ExecuteFunctionButton.tscn")
@onready var config_window := load("res://plugins/SSH/scenes/SSHConfigWindow.tscn")

func _exit_tree():
	if main_menu_button:
		main_menu_button.queue_free()


func _ready():
	load_client_config()
	if not main_menu_button:
		main_menu_button = execute_function_button.instantiate()
		main_menu_button.init("SSH Config", "/" + get_path().get_concatenated_names(), "show_config")
		get_node("/root/Main/MainMenu").add_custom_button(main_menu_button)


func _process(_delta):
	# Thread cleanup
	for thread in thread_pool:
		if not thread.is_alive():
			thread.wait_to_finish()
			thread_pool.erase(thread)


func show_config():
	if config_window_scene:
		return

	config_window_scene = config_window.instantiate()
	get_node("/root/Main").add_child(config_window_scene)


func hide_config():
	if not config_window_scene:
		return

	config_window_scene.queue_free()
	config_window_scene = null


func load_client_config():
	client_config.load_config()
	client_list = client_config.get_config()["ssh_clients"]
	for client in client_list:
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
	client_config.change_config({"ssh_clients": client_list})
	client_config.save()


func add_new_client(client_dict: Dictionary):
	client_list.push_back(client_dict)
	add_client(client_dict)


## [param client_dict] should contain: TODO
func add_client(client_dict: Dictionary):
	var ssh_client = SSHClient.new()
	ssh_client.name = client_dict["name"]
	add_child(ssh_client)
	edit_client_config(get_child_count() - 1, client_dict)


## edits also in client_list
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
	thread.start(Callable(ssh_client, "exec").bind(cmd))
	thread_pool.append(thread)
