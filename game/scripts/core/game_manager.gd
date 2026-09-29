extends Node

## GameManager
##
## Top-level coordinator. Owns the run lifecycle (title -> playing ->
## won / lost -> restart), the win and lose rules, the per-run stats
## shown on the end screen, and dispatches companion-task hotkeys.

signal day_number_changed(new_day: int)
signal camp_destroyed
signal companion_task_changed(companion: Node, task: int)
signal run_started
signal run_ended(won: bool, reason: String)

enum RunState { MENU, PLAYING, WON, LOST }

const TITLE_SCENE: String = "res://scenes/ui/TitleScreen.tscn"
const GAME_SCENE: String = "res://scenes/main/Main.tscn"

## Surviving this many nights wins the run.
@export var nights_to_win: int = 3

var current_day: int = 1
var is_camp_destroyed: bool = false
var run_state: int = RunState.MENU
var end_reason: String = ""
## Per-run counters for the end screen and the playtest log.
var stats: Dictionary = {}
## A save waiting to be applied once the gameplay scene is ready.
var _pending_save: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.theme = UiKit.theme()
	TimeManager.day_started.connect(_on_day_started)
	TimeManager.dawn_started.connect(_on_dawn_started)
	ResourceManager.resource_changed.connect(_on_resource_changed)
	ProgressionManager.xp_gained.connect(_on_xp_gained)
	_reset_stats()
	if "--selftest" in OS.get_cmdline_user_args():
		_run_selftest.call_deferred()


## `Campsite -- --selftest` checks an exported build can load its data
## and gameplay scene from the PCK, prints a summary, and exits.
func _run_selftest() -> void:
	var items: int = ResourceManager.get_definitions().size()
	var buildings: int = BuildManager.get_known_definitions().size()
	var recipes: int = CraftingManager.get_recipes().size()
	var scene: PackedScene = load(GAME_SCENE) as PackedScene
	var instance: Node = scene.instantiate() if scene != null else null
	var ok: bool = items >= 11 and buildings >= 2 and recipes >= 1 and instance != null
	print("selftest: items=%d buildings=%d recipes=%d main_scene=%s -> %s" % [
		items, buildings, recipes, instance != null, "OK" if ok else "FAILED"
	])
	if instance != null:
		instance.free()
	get_tree().quit(0 if ok else 1)


func _unhandled_input(event: InputEvent) -> void:
	if run_state != RunState.PLAYING or get_tree().paused:
		return
	if event.is_action_pressed("assign_idle"):
		assign_companion_task(0)
	elif event.is_action_pressed("assign_follow"):
		assign_companion_task(1)
	elif event.is_action_pressed("assign_guard"):
		assign_companion_task(2)
	elif event.is_action_pressed("assign_gather"):
		assign_companion_task(3)
	elif event.is_action_pressed("assign_repair"):
		assign_companion_task(4)
	elif event.is_action_pressed("skip_to_night"):
		if TimeManager.current_phase == TimeManager.Phase.DAY:
			TimeManager.skip_phase()


## Resets every autoload and loads the gameplay scene. `nights` picks
## the run length (3 or 7 from the title screen); 0 keeps the current
## one (Again / restart). A new run replaces any autosave.
func start_run(nights: int = 0) -> void:
	if nights > 0:
		nights_to_win = nights
	_pending_save = {}
	SaveManager.delete_save()
	get_tree().paused = false
	_reset_autoloads()
	LoadingScreen.load_scene(GAME_SCENE)  # key art while the camp loads (feature 029)


## Resumes the autosaved run at the morning after its last dawn.
## False if there is no usable save.
func continue_run() -> bool:
	var data: Dictionary = SaveManager.load_save()
	if data.is_empty():
		return false
	nights_to_win = int(data["nights_to_win"])
	get_tree().paused = false
	_reset_autoloads()
	_pending_save = data
	LoadingScreen.load_scene(GAME_SCENE)
	return true


func go_to_title() -> void:
	get_tree().paused = false
	_reset_autoloads()
	run_state = RunState.MENU
	get_tree().change_scene_to_file(TITLE_SCENE)


## Called by Main once the gameplay scene is in the tree.
func on_game_scene_ready() -> void:
	run_state = RunState.PLAYING
	_hook_base_core()
	_hook_player()
	if _pending_save.is_empty():
		TimeManager.start_run()
		PlaytestLog.write("run_started nights_to_win=%d" % nights_to_win)
	else:
		var data: Dictionary = _pending_save
		_pending_save = {}
		SaveManager.apply(data)
		TimeManager.start_run(int(data["day"]) + 1)
		PlaytestLog.write("run_continued nights_to_win=%d day=%d" % [nights_to_win, TimeManager.day_number])
	run_started.emit()


func is_playing() -> bool:
	return run_state == RunState.PLAYING


func record(stat: StringName, amount: int = 1) -> void:
	stats[stat] = int(stats.get(stat, 0)) + amount


func _reset_autoloads() -> void:
	TimeManager.reset()
	BuildManager.exit_build_mode()
	ResourceManager.reset()
	ProgressionManager.reset()
	current_day = 1
	is_camp_destroyed = false
	end_reason = ""
	_reset_stats()


func _reset_stats() -> void:
	stats = {
		&"kills": 0,
		&"gathered": 0,
		&"built": 0,
		&"crafted": 0,
		&"torches_placed": 0,
		&"repairs": 0,
		&"shards": 0,
		&"nights_survived": 0,
	}


func _end_run(won: bool, reason: String) -> void:
	if run_state != RunState.PLAYING:
		return
	run_state = RunState.WON if won else RunState.LOST
	end_reason = reason
	TimeManager.stop()
	BuildManager.exit_build_mode()
	PlaytestLog.write("run_ended won=%s reason=\"%s\" day=%d stats=%s" % [won, reason, current_day, stats])
	run_ended.emit(won, reason)
	# Freeze the world behind the end screen.
	get_tree().paused = true


func _on_day_started(day_number: int) -> void:
	current_day = day_number
	day_number_changed.emit(current_day)


func _on_dawn_started(day_number: int) -> void:
	if run_state != RunState.PLAYING:
		return
	stats[&"nights_survived"] = day_number
	PlaytestLog.write("night_survived night=%d" % day_number)
	if day_number >= nights_to_win:
		_end_run(true, "You survived %d nights!" % nights_to_win)


func _on_resource_changed(_id: StringName, _new_value: int, delta: int) -> void:
	# Only count gathering; crafting outputs are counted separately.
	if delta > 0 and run_state == RunState.PLAYING and not CraftingManager.is_crafting:
		record(&"gathered", delta)


func _on_xp_gained(_character: Node, _amount: int, source: StringName) -> void:
	if source == &"build":
		record(&"built")


## Public entry for the HUD's task buttons.
func assign_companion_task(task: int) -> void:
	_assign_to_all_companions(task)
	AudioManager.play_sfx(&"task")


func _assign_to_all_companions(task: int) -> void:
	for companion in get_tree().get_nodes_in_group("companions"):
		if companion.has_method("set_task"):
			companion.set_task(task)
			companion_task_changed.emit(companion, task)


func _hook_base_core() -> void:
	for node in get_tree().get_nodes_in_group("base_core"):
		if node.has_signal("destroyed") and not node.destroyed.is_connected(_on_camp_destroyed):
			node.destroyed.connect(_on_camp_destroyed)


func _hook_player() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node.has_signal("knocked_out") and not node.knocked_out.is_connected(_on_player_knocked_out):
			node.knocked_out.connect(_on_player_knocked_out)


func _on_camp_destroyed() -> void:
	if is_camp_destroyed:
		return
	is_camp_destroyed = true
	camp_destroyed.emit()
	_end_run(false, "The campfire went out.")


func _on_player_knocked_out() -> void:
	_end_run(false, "You were knocked out.")
