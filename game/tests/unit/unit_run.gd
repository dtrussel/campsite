extends Node

## unit_run.gd
##
## The unit-test pass: plays every test_*.gd script in tests/unit/, in
## file-name order, and every test_* method in each, without the
## gameplay scene. A scene, not a `-s` script, so the autoloads are up
## as in the game. A new module adds its own test script here and
## touches nothing else.
##
##   godot --headless --path game res://tests/unit/unit_run.tscn [-- options]
##
## Options (after `--`):
##   --unit <name>   play only tests/unit/<name>.gd (not `--test`,
##                   which Godot itself takes)
##
## Exits 0 on success, 1 on any failed check.

const TEST_DIR: String = "res://tests/unit"


func _ready() -> void:
	var only: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--unit":
			only = args[i + 1]
	var paths: PackedStringArray = _test_paths(only)
	var failures: int = 0
	var tests: int = 0
	if paths.is_empty():
		printerr("unit: FAIL no test script in %s matches '%s'" % [TEST_DIR, only])
		failures += 1
	for path in paths:
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			printerr("unit: FAIL %s loads" % path)
			failures += 1
			continue
		for method in _test_methods(script):
			print("unit: --- %s %s" % [path.get_file().get_basename(), method])
			# A fresh instance for every test, so no test sees another's state.
			var test: RefCounted = script.new()
			test.call(method)
			failures += int(test.get("failures"))
			tests += 1
	if failures == 0:
		print("unit: PASSED (%d tests)" % tests)
		get_tree().quit(0)
	else:
		printerr("unit: FAILED (%d)" % failures)
		get_tree().quit(1)


## The test scripts, sorted by file name; only `only`.gd if given.
func _test_paths(only: String) -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	for file in DirAccess.get_files_at(TEST_DIR):
		if file.get_extension() == "gd" and file.begins_with("test_") \
				and (only == "" or file.get_basename() == only):
			paths.append(TEST_DIR.path_join(file))
	paths.sort()
	return paths


## The script's own test_* methods, in the order they are written.
func _test_methods(script: GDScript) -> Array[String]:
	var out: Array[String] = []
	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_") and not out.has(method_name):
			out.append(method_name)
	return out
