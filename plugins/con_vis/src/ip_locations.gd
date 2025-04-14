extends Node3D

const _DEFAULT_LOCAL_COMMAND = "ss -tun | awk 'NR>1 {print \\$6}' | sed -E 's|^\\[?(.*[^]])\\]?:[^:]*$|\\1|'"
const _DEFAULT_SSH_COMMAND = "ss -tun | awk 'NR>1 {print $6}' | sed -E 's|^\\[?(.*[^]])\\]?:[^:]*$|\\1|'"

var use_ssh: bool = false
var ssh_client_uuid: String = ""
var custom_command: String = ""

var _request_node: HTTPRequest
var _ip_locations: Dictionary[String, IpLocation] = {}
var _ips: Array[String] = []
var _earth_radius: float
var _thread: Thread = Thread.new()
var _physics_process_timer: float = 0.0

@onready var earth: MeshInstance3D = %Earth
@onready var con_points: MultiMeshInstance3D = %ConPoints


func _ready() -> void:
	_request_node = HTTPRequest.new()
	add_child(_request_node)
	_request_node.request_completed.connect(_http_request_completed)

	_earth_radius = earth.mesh.radius


func _process(delta: float) -> void:
	earth.rotate_y(delta * 0.2)


func _physics_process(delta: float) -> void:
	_physics_process_timer += delta
	if _thread.is_started() and not _thread.is_alive():
		_thread.wait_to_finish()
	elif _physics_process_timer > 2.0:
		_physics_process_timer = 0.0
		_thread.start(get_ips)


## Naive for now, needs better filtering in the future, especially for ipv6
static func filter_private_ip(ip: String) -> bool:
	if ip.begins_with("::ffff:"):
		ip = ip.trim_prefix("::ffff:")
	if (
		ip.begins_with("192.168")
		or ip.begins_with("10.")
		or ip == "127.0.0.1"
		or ip.begins_with("fd")
		or ip == "::1"
	):
		return false

	return true


func get_ips() -> void:
	var output_string: String
	if use_ssh:
		if not PluginCoordinator.get_activated_plugins().has("SSH"):
			push_error("SSH plugin is not active")
			return
		var ssh_controller: SSHController = (
			PluginCoordinator.get_plugin_loader("SSH").get_controller("SSHController")
		)
		var clients: Dictionary = ssh_controller.get_clients()
		var client_uuid: String
		if ssh_client_uuid != "" and clients.values().has(ssh_client_uuid):
			client_uuid = ssh_client_uuid
		elif clients.size() > 0:
			client_uuid = clients.values()[0]
		else:
			push_error("No SSH clients available")
			return
		var cmd: String = custom_command if custom_command != "" else _DEFAULT_SSH_COMMAND
		var output: Dictionary = ssh_controller.get_client(client_uuid).get_client().exec_blocking(
			cmd
		)
		var exit_code: int = output.exit_status
		if exit_code != 0:
			push_error("Failed to get connections")
			return
		output_string = output.stdout
	else:
		var cmd: String = custom_command if custom_command != "" else _DEFAULT_LOCAL_COMMAND
		var output: Array = []
		var exit_code: int = OS.execute("bash", ["-c", cmd], output)
		if exit_code != 0 and output.size() <= 0:
			push_error("Failed to get connections")
			return
		output_string = output[0]

	var ips: Array[String]
	ips.assign(output_string.split("\n", false))
	ips = ips.filter(filter_private_ip)
	if ips == _ips:
		print("Same ips, skipping...")
		return

	_ips = ips
	handle_ips.call_deferred()


func handle_ips() -> void:
	var new_ips: Array[String] = []
	for ip in _ips:
		if not _ip_locations.has(ip):
			new_ips.append(ip)

	if new_ips.size() > 0:
		print("requesting...")
		request_ip_locations(new_ips)
	else:
		print("Knew all locations")
		to_points()


func request_ip_locations(ips: Array[String]) -> void:
	var body = JSON.stringify(ips)
	var error = _request_node.request(
		"http://ip-api.com/batch?fields=status,query,country,city,lat,lon",
		[],
		HTTPClient.METHOD_POST,
		body
	)
	if error != OK:
		push_error("An error occurred in the HTTP request.")


func _http_request_completed(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("http://ip-api request failed with code: %s" % result)
		return
	if response_code != 200:
		push_error("Failed to get locations from ip-api with response code: %s" % response_code)
		return
	var res: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not typeof(res) == TYPE_ARRAY:
		push_error("Failed to parse body to expected json")
		return

	for entry in res:
		if not _ips.has(entry.query):
			# IPv6 to IPv4 compat
			if _ips.has("::ffff:%s" % entry.query):
				entry.query = "::ffff:%s" % entry.query
			else:
				continue
		if entry.has("status") and entry.status != "success":
			push_error("Failed to get location for ip: %s" % entry.query)
			continue
		var ip_location: IpLocation = IpLocation.new()
		ip_location.country = entry.country
		ip_location.city = entry.city
		ip_location.lat = entry.lat
		ip_location.lon = entry.lon
		_ip_locations[entry.query] = ip_location

	print("Finished requesting")
	to_points()


func to_points() -> void:
	var multimesh: MultiMesh = con_points.multimesh
	var points_count: Dictionary[Vector3, int] = {}

	# Test locations (nuremberg, new_york)
	# var locations: Array[Dictionary] = [{"lat": 49.45, "lon": 11.07}, {"lat": 40.73, "lon": -73.93}]
	# for loc in locations:
	# var lat_rad: float = deg_to_rad(loc.lat)
	# var lon_rad: float = deg_to_rad(-loc.lon - 90)

	for ip in _ips:
		if not _ip_locations.has(ip) or not _ip_locations[ip]:
			continue
		var lat_rad: float = deg_to_rad(_ip_locations[ip].lat)
		var lon_rad: float = deg_to_rad(-_ip_locations[ip].lon - 90)
		var point: Vector3 = Vector3(
			_earth_radius * cos(lat_rad) * cos(lon_rad),
			_earth_radius * sin(lat_rad),
			_earth_radius * cos(lat_rad) * sin(lon_rad)
		)
		if points_count.has(point):
			points_count[point] += 1
		else:
			points_count[point] = 1

	multimesh.instance_count = points_count.size()
	multimesh.visible_instance_count = points_count.size()
	var i: int = 0
	for point in points_count:
		multimesh.set_instance_transform(
			i,
			Transform3D(
				Basis() * (1 + 3 * (points_count[point] / float(points_count.values().max()))),
				point
			)
		)
		i += 1


class IpLocation:
	var country: String
	var city: String
	var lat: float
	var lon: float

	func _to_string() -> String:
		return "IpEntry(country: %s, city: %s, lat: %s, lon: %s)" % [country, city, lat, lon]
