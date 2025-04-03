class_name TestMainLoop
extends MainLoop

var test_module_name: String = ""
var failed_tests: Array[String] = []
var fail_on_warn: bool = false
var test_stack: Array[String] = []


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	fail_on_warn = args.has("--fail-on-warn")
	test_stack.push_back(test_module_name)


# Workaround for not being able to set exit code in MainLoop
func set_exit_status(code: int) -> void:
	var scene_tree: SceneTree = SceneTree.new()
	scene_tree.quit(code)
	scene_tree.free()


func test_assert(value: bool, test: String) -> void:
	var test_name: String = "%s::%s" % [_test_name(), test]
	if not value:
		print_rich("[color=red]%s failed[/color]" % test_name)
		failed_tests.append(test_name)
		set_exit_status(1)
	else:
		print_rich("[color=green]%s succeeded[/color]" % test_name)


func test_assert_eq(value_expected: Variant, value_got: Variant, test: String) -> void:
	var test_name: String = "%s::%s" % [_test_name(), test]
	if typeof(value_expected) == typeof(value_got) and value_expected == value_got:
		print_rich("[color=green]%s succeeded[/color]" % test_name)
	else:
		print_rich("[color=red]%s failed\n\tExpected: %s, got: %s[/color]" % [test_name, value_expected, value_got])
		failed_tests.append(test_name)
		set_exit_status(1)


func warn(message: String) -> void:
	if fail_on_warn:
		print_rich("[color=red]%s: %s[/color]" % [_test_name(), message])
	else:
		print_rich("[color=yellow]%s: %s[/color]" % [_test_name(), message])


func subtest(fn: Callable) -> void:
	test_stack.push_back(fn.get_method())
	fn.call()
	test_stack.pop_back()


func _test_name() -> String:
	if test_stack.size() == 0:
		push_error("Error in test script: test_stack too small")
		return ""

	var ret: String = ""
	for test_string in test_stack:
		ret += "::%s" % test_string

	# Remove leading ::
	ret = ret.lstrip(':')
	return ret


func _finalize() -> void:
	print_rich("\n[color=red]Failed test for %s:[/color]" % test_module_name)
	for failed_test in failed_tests:
		print_rich("\t[color=red]%s[/color]" % failed_test.lstrip("%s::" % test_module_name))

	print_rich("[color=white]")
