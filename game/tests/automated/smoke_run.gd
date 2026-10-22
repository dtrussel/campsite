extends "res://tests/automated/smoke_scenario.gd"

## smoke_run.gd
##
## End-to-end headless smoke test for the playtest loop. Plays every
## scenario script in scenarios/, in file-name order, each from a clean
## slate; each one instances the real Main scene and drives it. A new
## feature adds its own scenario script there and touches nothing here.
##
##   godot --headless --path game res://tests/automated/smoke_run.tscn [-- options]
##
## Options (after `--`):
##   --scenario <name>   play only scenarios/<name>.gd
##
## Exits 0 on success, 1 on any failed check (or on timeout).

const SCENARIO_DIR: String = "res://tests/automated/scenarios"
const TIMEOUT_SECONDS: float = 180.0



func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var only: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--scenario":
			only = args[i + 1]
	get_tree().create_timer(TIMEOUT_SECONDS, true, false, true).timeout.connect(func() -> void:
		_fail("timed out after %ds" % TIMEOUT_SECONDS)
		_finish()
	)
	# Never touch a real player's autosave.
	SaveManager.set_save_path(TEST_SAVE_PATH)
	Profile.set_path(TEST_PROFILE_PATH)
	# The smoke run plays a debug build, which unlocks every chapter.
	Profile.unlock_all_chapters = false
	var paths: PackedStringArray = _scenario_paths(only)
	if paths.is_empty():
		_fail("no scenario script in %s matches '%s'" % [SCENARIO_DIR, only])
	for path in paths:
		await _reset()
		print("smoke: === %s" % path.get_file())
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			_fail("%s loads" % path)
			continue
		var scenario: Node = script.new()
		add_child(scenario)
		await scenario.call("run")
	await _reset()
	_finish()


## The scenario scripts, sorted by file name; only `only`.gd if given.
func _scenario_paths(only: String) -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	for file in DirAccess.get_files_at(SCENARIO_DIR):
		if file.get_extension() == "gd" and (only == "" or file.get_basename() == only):
			paths.append(SCENARIO_DIR.path_join(file))
	paths.sort()
	return paths


## A clean slate for the next scenario script: no camp, nothing left on
## the test root, no save, a fresh profile and story, Leo with Nela on a
## 3-night story run.
func _reset() -> void:
	await _close_main()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	SaveManager.delete_save()
	Profile.set_path(TEST_PROFILE_PATH)
	Profile.delete()
	StoryLibrary.forget_progress()
	GameManager.set_party(&"leo")
	GameManager.nights_to_win = 3
	GameManager.endless = false


func _finish() -> void:
	Engine.time_scale = 1.0
	if _failures == 0:
		print("smoke: PASSED (%d frames)" % Engine.get_process_frames())
		get_tree().quit(0)
	else:
		printerr("smoke: FAILED (%d)" % _failures)
		get_tree().quit(1)
