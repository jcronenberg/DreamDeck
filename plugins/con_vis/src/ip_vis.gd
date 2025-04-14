extends PluginSceneBase

@onready var _ip_locations: Node3D = $SubViewport/ConVis


func handle_config() -> void:
	var data: Dictionary = config.get_as_dict()
	_ip_locations.use_ssh = data["use_ssh"]
	var ssh_client = data.get("ssh_client")
	_ip_locations.ssh_client_uuid = ssh_client if ssh_client != null else ""
	_ip_locations.custom_command = data["custom_command"]


func init(init_scene_id: String) -> void:
	config.add_bool("Use SSH", "use_ssh", false)
	config.add_dict("SSH Client", "ssh_client", null, {})
	config.add_string("Custom Command", "custom_command", "")
	_refresh_ssh_clients()

	super(init_scene_id)


func scene_show() -> void:
	super()
	_ip_locations.set_process(true)
	_ip_locations.set_physics_process(true)


func scene_hide() -> void:
	super()
	_ip_locations.set_process(false)
	_ip_locations.set_physics_process(false)


func edit_config() -> void:
	_refresh_ssh_clients()
	super()


func _refresh_ssh_clients() -> void:
	if not PluginCoordinator.get_activated_plugins().has("SSH"):
		return
	var ssh_controller: SSHController = PluginCoordinator.get_plugin_loader("SSH").get_controller(
		"SSHController"
	)
	var clients: Dictionary = ssh_controller.get_clients()
	var ssh_client_object: Config.DictObject = config.get_object("ssh_client")
	ssh_client_object.set_dict(clients)
	if ssh_client_object.get_value() == null and clients.size() > 0:
		ssh_client_object.set_value(clients.values()[0])
