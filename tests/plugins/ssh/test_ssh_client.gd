class_name TestSSHClient
extends TestMainLoop


func _initialize() -> void:
	test_module_name = "SSHClient"
	super()


func _process(_delta: float) -> bool:
	subtest(test_key_gen)
	subtest(simple_tests)
	if not check_ssh_port(22):
		warn("Failed to connect to testing SSH port: 8022")
		if fail_on_warn:
			failed_tests.append("SSHClient")
			return true
		warn("Skipping SSHClient tests")
	else:
		subtest(client_to_server)
	return true


func check_ssh_port(port: int) -> bool:
	var peer: StreamPeerTCP = StreamPeerTCP.new()
	if peer.connect_to_host("127.0.0.1", port) != Error.OK:
		return false

	var timeout: int = 0
	while peer.get_status() == StreamPeerTCP.STATUS_CONNECTING or timeout > 1000:
		peer.poll()
		timeout += 1

	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false

	peer.disconnect_from_host()
	return true


func simple_tests() -> void:
	test_assert_eq(false, "hello", "different_types")
	test_assert_eq(false, true, "different_values")
	test_assert_eq("hello", "hello", "succeed")


func client_to_server() -> void:
	test_assert(test_ssh(), "exec_blocking")


func test_ssh() -> bool:
	var client: SSHClient = SSHClient.new()
	client.ip = "127.0.0.1"
	client.user = "jorik"
	client.set_auth_key_file("/home/jorik/.ssh/id_rsa", "")
	client.set_server_check_method("no_check")
	if client.exec_blocking("echo hi"):
		return true

	return false


func test_key_gen() -> void:
	test_assert(
		SSHClient.generate_private_key("ED25519", 0, "test-ed@testing") != "", "gen_ed25519"
	)
	# test_assert(SSHClient.generate_private_key("RSA", 2048, "test-rsa@testing") != "", "gen_rsa")

	# var key: SSHKey = SSHKey.new()
	# key.gen_uuid()
	# key.key_data = Marshalls.utf8_to_base64(
	# 	SSHClient.generate_private_key("ED25519", 0, "test-ed@testing")
	# )
