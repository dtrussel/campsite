extends Node

## What every smoke scenario script (scenarios/*.gd) extends: the camp
## the scenarios play in, the waits, and the ok/FAIL reporting.
## smoke_run.gd plays the scenario scripts.
##
## A scenario script defines `run()`, which plays its checks in order.
## Each script starts from a clean slate (no camp, save or profile, Leo
## with Nela, a 3-night story run), so no script depends on another.

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const SPEED: float = 4.0
const TEST_SAVE_PATH: String = "user://smoke_save.json"
const TEST_PROFILE_PATH: String = "user://smoke_profile.json"

## Shared by every scenario: the camp now open, and the checks failed.
static var _main: Node = null
static var _failures: int = 0


## The smoke run's config: a 3-night Chapter 1 run of Leo with Nela,
## with the smoke settings (_run_of).
func _config(auto_pick_seconds: float = 0.0, perk_seed: int = 1, loot_seed: int = 1) -> RunConfig:
	return _run_of(RunConfig.for_chapter(1), auto_pick_seconds, perk_seed, loot_seed)


## `run` (a config of any shape) with the smoke settings: a fixed perk
## deal and loot sequence (the same cards and drops every run), no day
## chest unless a check asks for one, and level-ups that take the first
## card at once unless `auto_pick_seconds` > 0.
func _run_of(run: RunConfig, auto_pick_seconds: float = 0.0, perk_seed: int = 1, loot_seed: int = 1) -> RunConfig:
	run.perk_auto_pick_seconds = auto_pick_seconds
	run.perk_seed = perk_seed
	run.loot_seed = loot_seed
	run.day_chest_day = 0
	return run


## Again, as the end screen plays it: the last run's config with fresh
## seeds (GameManager.start_run), with the smoke settings.
func _again(auto_pick_seconds: float = 0.0) -> RunConfig:
	return _run_of(RunSession.config.again(), auto_pick_seconds)


## _config() with `hero` played (and their default companion).
func _party(hero: StringName, auto_pick_seconds: float = 0.0) -> RunConfig:
	var config: RunConfig = _config(auto_pick_seconds)
	config.set_party(hero)
	return config


## A new run through the run session, from `config` (_config() when
## null: Chapter 1 with Leo and Nela, the smoke seeds, no picker).
func _start_fresh_run(config: RunConfig = null) -> void:
	await _close_main()
	RunSession.start(config if config != null else _config(), false)
	await _open_main()


## Continues `data` through the run session, as Continue on the title
## screen does: the run config comes from the save, the seeds and the
## auto-pick time from `config` (_config() when null).
func _continue_from(data: Dictionary, config: RunConfig = null) -> void:
	await _close_main()
	_check(RunSession.continue_from(data, config if config != null else _config(), false),
		"the run session takes the save to continue")
	await _open_main()


## Continues the camp from its own save with `xp` for the hero in `role`,
## so its level-ups are replayed from the save. The save is made as if
## from before perk cards, so Continue deals no card that is owed.
func _continue_with_xp(role: StringName, xp: int, config: RunConfig = null) -> void:
	var data: Dictionary = RunSession.snapshot()
	(data[Party.SAVE_KEYS[role]] as Dictionary)["xp"] = xp
	for key in Party.SAVE_KEYS.values():
		(data[key] as Dictionary).erase("perks")
	await _continue_from(SaveManager.parse(SaveManager.serialize(data)), config)


func _close_main() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if _main != null:
		# Wait until the old camp is really gone: resuming from a physics-
		# frame timer, one process frame can still run before it is freed.
		var old: Node = _main
		old.queue_free()
		while is_instance_valid(old):
			await get_tree().process_frame
		_main = null


func _open_main() -> void:
	_main = MAIN_SCENE.instantiate()
	get_tree().current_scene.add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	# The controls overlay pauses the game at run start; dismiss it.
	var overlay: Node = get_tree().get_first_node_in_group("controls_overlay")
	_check(overlay != null and overlay.is_open(), "controls overlay shown at run start")
	_check(get_tree().paused, "game paused while overlay open")
	overlay.close()
	_check(not get_tree().paused, "game unpaused after closing overlay")
	# Scenarios stage mobs next to the hero; only _check_auto_attack
	# lets the hero fight them on its own.
	for player in get_tree().get_nodes_in_group("player"):
		player.set("auto_attack", false)
	Engine.time_scale = SPEED


func _find_resource_node(item_id: StringName) -> ResourceNode:
	for node in get_tree().current_scene.find_children("*", "ResourceNode", true, false):
		var resource_node: ResourceNode = node as ResourceNode
		if resource_node.definition != null and resource_node.definition.id == item_id and resource_node.is_gatherable:
			return resource_node
	return null


func _campfire() -> BaseCore:
	return get_tree().get_first_node_in_group("base_core") as BaseCore


func _spawn_mob(definition: MobDefinition, position: Vector3) -> Mob:
	var mob: Mob = definition.get_scene().instantiate() as Mob
	get_tree().current_scene.add_child(mob)
	mob.global_position = position
	return mob


func _spawn_building(id: StringName, position: Vector3) -> Building:
	var building: Building = BuildManager.get_definition(id).get_scene().instantiate() as Building
	get_tree().current_scene.add_child(building)
	building.global_position = position
	return building


func _recipe(id: StringName) -> CraftingRecipe:
	for recipe in CraftingManager.get_recipes():
		if recipe.id == id:
			return recipe
	return null


func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


## Opens the title screen and returns its captioned buttons, as
## {lower-case caption: tooltip}. The screen is gone again by the time
## this returns.
func _title_buttons() -> Dictionary:
	var game_camera: Camera3D = get_viewport().get_camera_3d()
	var title: Control = (load("res://scenes/ui/TitleScreen.tscn") as PackedScene).instantiate()
	add_child(title)
	await get_tree().process_frame
	var found: Dictionary = {}
	for node in title.find_children("*", "Button", true, false):
		var caption: String = (node as Button).text.strip_edges().to_lower()
		if caption != "":
			found[caption] = (node as Button).tooltip_text
	title.free()
	if game_camera != null and is_instance_valid(game_camera):
		game_camera.make_current()
	return found


## Skips day, sunset and night phases until night `night` has dawned.
func _skip_to_dawn(night: int) -> void:
	while GameManager.is_playing() and int(GameManager.stats[&"nights_survived"]) < night:
		TimeManager.skip_phase()
		await get_tree().process_frame


## Skips the clock on to the next night; stops if the clock has stopped
## (the run ended), so a check fails instead of the test hanging.
func _skip_to_night() -> void:
	for i in 4:
		if TimeManager.is_night() or not TimeManager.is_running:
			return
		TimeManager.skip_phase()


## Removes the staged mobs without a kill, so no XP (and no level-up
## card) comes of it.
func _clear_staged_mobs() -> void:
	for node in get_tree().get_nodes_in_group("mobs"):
		node.remove_from_group("mobs")
		node.queue_free()
	await get_tree().process_frame


## Plants a torch with the hero's Q action and returns it.
func _plant_torch(player: Node3D) -> Node3D:
	var before: Array[Node] = get_tree().get_nodes_in_group("torches")
	player.call("try_place_torch")
	for node in get_tree().get_nodes_in_group("torches"):
		if not before.has(node):
			player.global_position += Vector3(0, 0, 2.0)
			return node as Node3D
	return null


func _bark_line(text: String, trigger: StringName, speaker: StringName) -> bool:
	for line in BarkLibrary.lines_for(trigger, speaker, RunSession.config.hero_id):
		if String((line as Dictionary).get("text", "")) == text:
			return true
	return false


## Waits `game_seconds` of game time, counted by the same frame deltas
## the game runs on. A real-time wait (`game_seconds / SPEED` of wall
## clock) ends early on a slow machine, where fewer frames fit in it;
## this one also stretches with a hit-stop or the perk picker's slow-down.
func _wait(game_seconds: float) -> void:
	await get_tree().create_timer(game_seconds, true, false, false).timeout


## Waits frame by frame until `condition` holds, for at most
## `game_seconds` of game time; returns whether it held. For an event a
## tween or a physics tick brings (a pebble landing, a glow fading): a
## fixed _wait just past it can end in the same long frame, before the
## tween steps (timers run first), and a longer one can outlast what
## the event leaves behind (a 1.5 s glow).
func _wait_until(condition: Callable, game_seconds: float) -> bool:
	var timer: SceneTreeTimer = get_tree().create_timer(game_seconds, true, false, false)
	while not condition.call():
		if timer.time_left <= 0.0:
			return false
		await get_tree().process_frame
	return true


func _check(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok   - " + label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures += 1
	printerr("smoke: FAIL - " + label)
