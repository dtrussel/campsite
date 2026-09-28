extends Node

## smoke_run.gd
##
## End-to-end headless smoke test for the playtest loop. Instances the
## real Main scene and drives it through a whole run:
##   gather -> craft a torch -> plant it -> survive 3 nights -> win,
## then a second run that loses when the campfire is destroyed.
##
##   godot --headless --path game res://tests/automated/smoke_run.tscn
##
## Exits 0 on success, 1 on the first failed check (or on timeout).

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const TIMEOUT_SECONDS: float = 180.0
const SPEED: float = 4.0

var _main: Node = null
var _failures: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(TIMEOUT_SECONDS, true, false, true).timeout.connect(func() -> void:
		_fail("timed out after %ds" % TIMEOUT_SECONDS)
		_finish()
	)
	await _run_win_scenario()
	await _run_loss_scenario()
	_finish()


func _run_win_scenario() -> void:
	print("smoke: --- win scenario ---")
	await _start_fresh_run()
	_check(GameManager.is_playing(), "run is PLAYING after scene load")
	_check(TimeManager.is_running, "clock is running")
	_check(ResourceManager.get_definitions().size() >= 11, "items loaded (%d)" % ResourceManager.get_definitions().size())
	_check(BuildManager.get_known_definitions().size() == 2, "2 buildings loaded")
	_check(CraftingManager.get_recipes().size() >= 1, "recipes loaded")

	var player: Node3D = get_tree().get_first_node_in_group("player")
	var companion: Node3D = get_tree().get_first_node_in_group("companions")
	_check(player != null and companion != null, "player and companion exist")

	# Gather from a tree: wood plus the leaves bonus.
	var tree_node: ResourceNode = _find_resource_node(&"wood")
	_check(tree_node != null, "found a tree")
	_check(tree_node.begin_gather(player), "gather started")
	await _wait(tree_node.gather_time_seconds + 0.3)
	_check(ResourceManager.get_count(&"wood") >= 2, "gathered wood")
	_check(ResourceManager.get_count(&"leaves") >= 1, "tree bonus gave leaves")
	_check(ProgressionManager.get_xp(player) > 0, "gather awarded XP")

	# Pine gives resin, bush gives fiber: every torch/fence input is reachable.
	var pine: ResourceNode = _find_resource_node(&"resin")
	_check(pine != null and pine.begin_gather(player), "gather from pine")
	await _wait(pine.gather_time_seconds + 0.3)
	_check(ResourceManager.get_count(&"resin") >= 1, "gathered resin")

	# Craft and plant a torch.
	var torch_recipe: CraftingRecipe = CraftingManager.get_recipes()[0]
	_check(CraftingManager.craft(torch_recipe, player), "crafted a torch")
	_check(ResourceManager.get_count(&"torch") == 1, "torch in inventory")
	player.call("_try_place_torch")
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("torches").size() == 1, "torch planted")
	_check(ResourceManager.get_count(&"torch") == 0, "torch consumed")

	# A fence instance loads and takes damage.
	var fence_def: BuildingDefinition = BuildManager.get_known_definitions()[0]
	var fence: Building = fence_def.get_scene().instantiate() as Building
	get_tree().current_scene.add_child(fence)
	fence.global_position = Vector3(0, 0, -4)
	fence.take_damage(5)
	_check(fence.current_hp == fence_def.max_hp - 5, "fence takes damage")

	companion.call("set_task", 2)  # guard the campfire
	for night in range(1, GameManager.nights_to_win + 1):
		await _survive_night(night, player)
		if night < GameManager.nights_to_win:
			_check(GameManager.is_playing(), "still playing after night %d" % night)
	_check(GameManager.run_state == GameManager.RunState.WON, "run WON after %d nights" % GameManager.nights_to_win)
	_check(int(GameManager.stats[&"kills"]) > 0, "kills recorded (%d)" % GameManager.stats[&"kills"])
	_check(get_tree().paused, "world frozen behind end screen")


func _survive_night(night: int, player: Node3D) -> void:
	# Fast-forward: day -> sunset -> night.
	while TimeManager.current_phase != TimeManager.Phase.NIGHT:
		TimeManager.skip_phase()
	# Let the imps arrive and hit things for a few seconds, then clear
	# every imp as it appears. Killing the whole wave brings dawn early.
	var kills_before: int = int(GameManager.stats[&"kills"])
	var elapsed: float = 0.0
	while TimeManager.current_phase == TimeManager.Phase.NIGHT and elapsed < 120.0:
		await _wait(0.5)
		elapsed += 0.5
		if elapsed > 6.0:
			for mob in get_tree().get_nodes_in_group("mobs"):
				mob.take_damage(999, player)
	_check(elapsed < TimeManager.night_seconds, "night %d ended early by clearing the wave (%.1fs)" % [night, elapsed])
	_check(int(GameManager.stats[&"kills"]) > kills_before, "night %d: player got kills" % night)
	_check(int(GameManager.stats[&"nights_survived"]) == night, "night %d counted as survived" % night)
	print("smoke: night %d cleared, campfire hp=%d" % [night, _campfire().current_hp])


func _run_loss_scenario() -> void:
	print("smoke: --- loss scenario ---")
	await _start_fresh_run()
	_check(GameManager.is_playing(), "second run is PLAYING")
	_check(ResourceManager.get_count(&"wood") == 0, "inventory reset between runs")
	var player: Node = get_tree().get_first_node_in_group("player")
	_check(ProgressionManager.get_level(player) == 1 and ProgressionManager.get_xp(player) == 0, "progression reset")
	_campfire().take_damage(10000)
	await get_tree().process_frame
	_check(GameManager.run_state == GameManager.RunState.LOST, "run LOST when campfire destroyed")


func _start_fresh_run() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if _main != null:
		_main.queue_free()
		await get_tree().process_frame
		GameManager.call("_reset_autoloads")
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	# The controls overlay pauses the game at run start; dismiss it.
	var overlay: Node = get_tree().get_first_node_in_group("controls_overlay")
	_check(overlay != null and overlay.is_open(), "controls overlay shown at run start")
	_check(get_tree().paused, "game paused while overlay open")
	overlay.close()
	_check(not get_tree().paused, "game unpaused after closing overlay")
	Engine.time_scale = SPEED


func _find_resource_node(item_id: StringName) -> ResourceNode:
	for node in get_tree().current_scene.find_children("*", "ResourceNode", true, false):
		var resource_node: ResourceNode = node as ResourceNode
		if resource_node.definition != null and resource_node.definition.id == item_id and resource_node.is_gatherable:
			return resource_node
	return null


func _campfire() -> BaseCore:
	return get_tree().get_first_node_in_group("base_core") as BaseCore


func _wait(game_seconds: float) -> void:
	await get_tree().create_timer(game_seconds / Engine.time_scale, true, false, true).timeout


func _check(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok   - " + label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures += 1
	printerr("smoke: FAIL - " + label)


func _finish() -> void:
	Engine.time_scale = 1.0
	if _failures == 0:
		print("smoke: PASSED")
		get_tree().quit(0)
	else:
		printerr("smoke: FAILED (%d)" % _failures)
		get_tree().quit(1)
