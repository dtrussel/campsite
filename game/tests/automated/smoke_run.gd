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
## The autosave written after night 1 of the win run (feature 020).
var _night1_save: Dictionary = {}

const TEST_SAVE_PATH: String = "user://smoke_save.json"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(TIMEOUT_SECONDS, true, false, true).timeout.connect(func() -> void:
		_fail("timed out after %ds" % TIMEOUT_SECONDS)
		_finish()
	)
	# Never touch a real player's autosave.
	SaveManager.set_save_path(TEST_SAVE_PATH)
	SaveManager.delete_save()
	await _run_win_scenario()
	await _run_loss_scenario()
	await _run_continue_scenario()
	SaveManager.delete_save()
	_finish()


func _run_win_scenario() -> void:
	print("smoke: --- win scenario ---")
	await _start_fresh_run()
	_check(GameManager.is_playing(), "run is PLAYING after scene load")
	_check(TimeManager.is_running, "clock is running")
	_check(ResourceManager.get_definitions().size() >= 11, "items loaded (%d)" % ResourceManager.get_definitions().size())
	_check(BuildManager.get_known_definitions().size() == 7, "7 buildings loaded")
	_check(CraftingManager.get_recipes().size() >= 1, "recipes loaded")

	var player: Node3D = get_tree().get_first_node_in_group("player")
	var companion: Node3D = get_tree().get_first_node_in_group("companions")
	_check(player != null and companion != null, "player and companion exist")

	# Audio: the day tune plays, and one-shots from the pool never error.
	var library: AudioLibrary = AudioManager.library
	_check(library != null and library.music_day != null, "audio library loaded")
	_check(AudioManager.mood == &"day", "day music mood at run start (%s)" % AudioManager.mood)
	for id in library.volumes.keys():
		AudioManager.play_sfx(StringName(id), player.global_position)
	AudioManager.play_sfx(&"no_such_sound")  # unknown ids are ignored

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
	var torch_recipe: CraftingRecipe = _recipe(&"torch")
	_check(CraftingManager.craft(torch_recipe, player), "crafted a torch")
	_check(ResourceManager.get_count(&"torch") == 1, "torch in inventory")
	player.call("_try_place_torch")
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("torches").size() == 1, "torch planted")
	_check(ResourceManager.get_count(&"torch") == 0, "torch consumed")

	# A fence instance loads and takes damage.
	var fence_def: BuildingDefinition = BuildManager.get_definition(&"wooden_fence")
	var fence: Building = fence_def.get_scene().instantiate() as Building
	get_tree().current_scene.add_child(fence)
	fence.global_position = Vector3(0, 0, -4)
	fence.take_damage(5)
	_check(fence.current_hp == fence_def.max_hp - 5, "fence takes damage")

	await _check_feature_017(player, companion, fence)

	# LoL-style commands: navmesh, move, gather, attack.
	var nav: NavigationRegion3D = get_tree().current_scene.find_child("Navigation", true, false) as NavigationRegion3D
	var waited_nav: float = 0.0
	while (nav == null or nav.navigation_mesh == null or nav.navigation_mesh.get_polygon_count() == 0) and waited_nav < 8.0:
		await _wait(0.25)
		waited_nav += 0.25
	_check(nav != null and nav.navigation_mesh.get_polygon_count() > 0, "navmesh baked (%d polys)" % (nav.navigation_mesh.get_polygon_count() if nav != null else 0))
	var goal: Vector3 = Vector3(-6, 0, 10)
	player.command_move(goal)
	var t: float = 0.0
	while int(player.get("command")) != 0 and t < 10.0:
		await _wait(0.25)
		t += 0.25
	var moved: float = Vector2(player.global_position.x - goal.x, player.global_position.z - goal.z).length()
	_check(moved < 1.0, "right-click move arrived (%.2f m off, %.1fs)" % [moved, t])

	await _check_animation_layers(player)

	var rock: ResourceNode = _find_resource_node(&"stone")
	var stone_before: int = ResourceManager.get_count(&"stone")
	player.command_gather(rock)
	t = 0.0
	while ResourceManager.get_count(&"stone") == stone_before and t < 15.0:
		await _wait(0.25)
		t += 0.25
	_check(ResourceManager.get_count(&"stone") > stone_before, "gather command walked over and gathered (%.1fs)" % t)

	var target_imp: Mob = (load("res://scenes/mobs/ShadowImp.tscn") as PackedScene).instantiate() as Mob
	get_tree().current_scene.add_child(target_imp)
	target_imp.global_position = player.global_position + Vector3(3.5, 0, 0)
	var kills_before_cmd: int = int(GameManager.stats[&"kills"])
	player.command_attack(target_imp)
	t = 0.0
	while is_instance_valid(target_imp) and target_imp.current_hp > 0 and t < 15.0:
		await _wait(0.25)
		t += 0.25
	_check(int(GameManager.stats[&"kills"]) > kills_before_cmd, "attack command chased and auto-attacked an imp to death (%.1fs)" % t)
	player.stop_commands()

	# Watch Post pelts a nearby imp on its own.
	var post_def: BuildingDefinition = BuildManager.get_definition(&"watch_post")
	var post: Building = post_def.get_scene().instantiate() as Building
	get_tree().current_scene.add_child(post)
	post.global_position = Vector3(12, 0, 12)
	var imp: Mob = (load("res://scenes/mobs/ShadowImp.tscn") as PackedScene).instantiate() as Mob
	get_tree().current_scene.add_child(imp)
	imp.global_position = Vector3(14, 0, 12)
	imp.set_physics_process(false)  # hold still for the check
	var imp_hp: int = imp.current_hp
	await _wait(post.auto_attack_interval + 0.5)
	_check(imp.current_hp < imp_hp, "watch post damaged a nearby imp (%d -> %d)" % [imp_hp, imp.current_hp])
	imp.take_damage(999, player)

	companion.call("set_task", 2)  # guard the campfire
	for night in range(1, GameManager.nights_to_win + 1):
		await _survive_night(night, player)
		if night == 1:
			await get_tree().process_frame  # the autosave runs deferred
			_night1_save = SaveManager.load_save()
			_check(not _night1_save.is_empty() and int(_night1_save["day"]) == 1, "autosaved at dawn after night 1")
			_check(int(_night1_save.get("inventory", {}).get("wood", 0)) == ResourceManager.get_count(&"wood"),
				"autosave has the inventory (wood %d)" % ResourceManager.get_count(&"wood"))
		if night < GameManager.nights_to_win:
			_check(GameManager.is_playing(), "still playing after night %d" % night)
	_check(GameManager.run_state == GameManager.RunState.WON, "run WON after %d nights" % GameManager.nights_to_win)
	_check(int(GameManager.stats[&"kills"]) > 0, "kills recorded (%d)" % GameManager.stats[&"kills"])
	_check(get_tree().paused, "world frozen behind end screen")
	_check(AudioManager.mood == &"", "music stops for the win stinger")
	_check(not SaveManager.has_save(), "a won run deletes its save")
	var shards_seen: int = ResourceManager.get_count(&"glow_shards") + get_tree().get_nodes_in_group("pickups").size()
	_check(shards_seen >= int(GameManager.stats[&"kills"]) / 3 - 1, "imps dropped glow shards (%d for %d kills)" % [shards_seen, GameManager.stats[&"kills"]])


## Feature 017: repair, the new resources, recipes, traps and lanterns.
func _check_feature_017(player: Node3D, companion: Node3D, fence: Building) -> void:
	# New resource nodes all gather.
	for item in [&"clay", &"mushrooms", &"scrap"]:
		var node: ResourceNode = _find_resource_node(item)
		_check(node != null and node.begin_gather(player), "gather started on %s" % item)
		if node != null:
			await _wait(node.gather_time_seconds + 0.3)
		_check(ResourceManager.get_count(item) >= 1, "gathered %s" % item)

	# Repair: one tap spends a wood and fixes the fence.
	ResourceManager.add(&"wood", 5)
	var wood_before: int = ResourceManager.get_count(&"wood")
	var hp_before: int = fence.current_hp
	_check(Repair.needs_repair(fence), "damaged fence needs repair")
	_check(Repair.tap(fence, player), "repair tap succeeded")
	_check(fence.current_hp > hp_before and ResourceManager.get_count(&"wood") == wood_before - 1,
		"repair restored HP (%d -> %d) for 1 wood" % [hp_before, fence.current_hp])
	_check(not Repair.needs_repair(fence), "fence fully repaired")

	# Leo's repair command walks over and hammers.
	fence.take_damage(20)
	player.command_repair(fence)
	var t: float = 0.0
	while Repair.needs_repair(fence) and t < 10.0:
		await _wait(0.25)
		t += 0.25
	_check(not Repair.needs_repair(fence), "repair command fixed the fence (%.1fs)" % t)

	# Nela's Repair task fixes the campfire.
	var fire: BaseCore = _campfire()
	fire.take_damage(30)
	companion.call("set_task", 4)
	t = 0.0
	while fire.get_missing_hp() > 0 and t < 15.0:
		await _wait(0.25)
		t += 0.25
	_check(fire.get_missing_hp() == 0, "Nela repaired the campfire (%.1fs)" % t)
	companion.call("set_task", 0)

	# Feed the Fire only while the campfire is damaged.
	var feed: CraftingRecipe = _recipe(&"feed_fire")
	_check(feed != null and not CraftingManager.can_craft(feed), "feed the fire disabled at full HP")
	fire.take_damage(25)
	var fire_hp: int = fire.current_hp
	_check(CraftingManager.craft(feed, player) and fire.current_hp == fire_hp + fire.repair_per_tap, "fed the fire (+%d)" % fire.repair_per_tap)

	# Stone Hearth: once per run, more max HP.
	ResourceManager.add(&"clay", 5)
	ResourceManager.add(&"stone", 4)
	var hearth: CraftingRecipe = _recipe(&"stone_hearth")
	var max_before: int = fire.max_hp
	_check(CraftingManager.craft(hearth, player), "built the stone hearth")
	_check(fire.has_hearth and fire.max_hp == max_before + fire.hearth_bonus_hp and fire.current_hp == fire.max_hp,
		"hearth raised campfire max HP to %d and healed it" % fire.max_hp)
	ResourceManager.add(&"clay", 5)
	ResourceManager.add(&"stone", 4)
	_check(not CraftingManager.can_craft(hearth), "hearth only once per run")

	# Berry Snack: crafted, then eaten first with R.
	ResourceManager.add(&"berries", 2)
	ResourceManager.add(&"mushrooms", 1)
	_check(CraftingManager.craft(_recipe(&"berry_snack"), player) and ResourceManager.get_count(&"snack") == 1, "cooked a berry snack")
	player.set("_invulnerable_remaining", 0.0)
	player.take_damage(40)
	var hp: int = player.current_hp
	player.call("_try_eat_berries")
	_check(player.current_hp == hp + int(player.heal_per_snack) and ResourceManager.get_count(&"snack") == 0,
		"ate the snack (+%d HP)" % player.heal_per_snack)

	# Snap trap: holds and hurts the first imp, uses a charge.
	var trap: SnapTrap = (load("res://scenes/buildings/SnapTrap.tscn") as PackedScene).instantiate() as SnapTrap
	get_tree().current_scene.add_child(trap)
	trap.global_position = Vector3(-14, 0, -4)
	var trapped: Mob = (load("res://scenes/mobs/ShadowImp.tscn") as PackedScene).instantiate() as Mob
	get_tree().current_scene.add_child(trapped)
	trapped.global_position = Vector3(-14, 0, -4.2)
	var trapped_hp: int = trapped.current_hp
	t = 0.0
	while trap.current_hp == 3 and t < 5.0:
		await _wait(0.1)
		t += 0.1
	_check(trap.current_hp == 2 and trapped.current_hp < trapped_hp and trapped.is_stunned(),
		"snap trap caught an imp (hp %d -> %d, charges left %d)" % [trapped_hp, trapped.current_hp, trap.current_hp])
	trapped.take_damage(999, player)

	# Glow Lantern: a permanent aura that slows and zaps imps.
	var lantern: Building = (load("res://scenes/buildings/GlowLantern.tscn") as PackedScene).instantiate() as Building
	get_tree().current_scene.add_child(lantern)
	lantern.global_position = Vector3(14, 0, -4)
	var zapped: Mob = (load("res://scenes/mobs/ShadowImp.tscn") as PackedScene).instantiate() as Mob
	get_tree().current_scene.add_child(zapped)
	zapped.global_position = Vector3(12, 0, -4)
	zapped.set_physics_process(false)
	var zapped_hp: int = zapped.current_hp
	await _wait(2.3)
	_check(zapped.call("_torch_slow_factor") < 1.0, "lantern aura slows imps")
	_check(zapped.current_hp < zapped_hp, "lantern aura zaps imps (%d -> %d)" % [zapped_hp, zapped.current_hp])
	zapped.take_damage(999, player)
	var aura: Node = lantern.get_node("Aura")
	_check(not TimeManager.dawn_started.is_connected(aura.get("_on_dawn_started")), "lantern aura does not burn out at dawn")
	lantern.queue_free()

	await _check_bramble_beast(player)
	await _check_feature_019(player, companion)
	await _check_mushroom_gremlin(player)


## Feature 019: stash caps, the Storage Crate, the Reinforced Wall and
## the Crafting Table recipes.
func _check_feature_019(player: Node3D, companion: Node3D) -> void:
	# Caps: 20 wood, 40 with a crate; losing the crate keeps what you have.
	ResourceManager.add(&"wood", 100)
	_check(ResourceManager.get_count(&"wood") == 20 and ResourceManager.is_full(&"wood"), "wood caps at 20")
	var crate: Building = _spawn_building(&"storage_crate", Vector3(-6, 0, -12))
	await get_tree().process_frame
	_check(ResourceManager.get_cap(&"wood") == 40, "a storage crate raises the cap to 40")
	ResourceManager.add(&"wood", 100)
	_check(ResourceManager.get_count(&"wood") == 40, "wood fills to 40")
	crate.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(ResourceManager.get_cap(&"wood") == 20 and ResourceManager.get_count(&"wood") == 40,
		"losing the crate lowers the cap but keeps the wood")
	ResourceManager.spend(&"wood", 25)

	# The Reinforced Wall is 3x a fence; a beast still does 12 a hit.
	var wall: Building = _spawn_building(&"reinforced_wall", Vector3(-8, 0, 14))
	_check(wall.current_hp == 150 and wall.is_in_group(Repair.GROUP), "reinforced wall has 150 HP and is repairable")
	var beast_def: MobDefinition = get_tree().get_first_node_in_group("mob_spawner").get("heavy_definition")
	var beast: Mob = beast_def.get_scene().instantiate() as Mob
	get_tree().current_scene.add_child(beast)
	beast.global_position = Vector3(-8, 0, 16.5)
	var t: float = 0.0
	while wall.current_hp == 150 and t < 15.0:
		await _wait(0.25)
		t += 0.25
	_check(wall.current_hp == 138, "beast hits the wall for 12 (%d left)" % wall.current_hp)
	beast.take_damage(999, player)
	wall.queue_free()

	# Crafting Table recipes are locked until a table stands in the camp.
	for item in [&"wood", &"scrap", &"resin", &"fiber", &"leaves"]:
		ResourceManager.add(item, 10)
	var stick: CraftingRecipe = _recipe(&"sturdy_stick")
	_check(stick.station == CraftingRecipe.STATION_TABLE and not CraftingManager.can_craft(stick), "table recipes locked without a table")
	var table: Building = _spawn_building(&"crafting_table", Vector3(5, 0, -6))
	_check(CraftingManager.has_table() and CraftingManager.can_craft(stick), "a crafting table unlocks them")
	var damage: int = int(player.get("attack_damage"))
	_check(CraftingManager.craft(stick, player) and int(player.get("attack_damage")) == damage + 2, "sturdy stick: +2 attack")
	_check(not CraftingManager.can_craft(stick), "sturdy stick only once")
	var reach: float = companion.call("get_attack_range")
	_check(CraftingManager.craft(_recipe(&"slingshot"), player) and is_equal_approx(companion.call("get_attack_range"), reach * 2.0),
		"slingshot doubles Nela's reach")

	# Bandage wakes a knocked-out Nela (X next to her).
	_check(CraftingManager.craft(_recipe(&"bandage"), player) and ResourceManager.get_count(&"bandage") == 1, "made a bandage")
	companion.set("_invulnerable_remaining", 0.0)
	companion.take_damage(999)
	_check(bool(companion.get("is_knocked_out")), "Nela knocked out")
	companion.global_position = player.global_position + Vector3(1.0, 0, 0)
	_check(player.call("try_use_bandage") and not bool(companion.get("is_knocked_out")) and ResourceManager.get_count(&"bandage") == 0,
		"bandage woke Nela up (%d HP)" % companion.get("current_hp"))

	# Trap Refill restores a used trap.
	var refill: CraftingRecipe = _recipe(&"trap_refill")
	var trap: SnapTrap = _spawn_building(&"snap_trap", Vector3(-14, 0, 8)) as SnapTrap
	for other in get_tree().get_nodes_in_group(SnapTrap.GROUP):
		(other as SnapTrap).recharge()  # the 017 trap has used a snap
	_check(not CraftingManager.can_craft(refill), "trap refill needs a used trap")
	trap.current_hp = 1
	_check(CraftingManager.craft(refill, player) and trap.current_hp == 3, "trap refill restored all snaps")
	trap.queue_free()
	table.queue_free()
	await get_tree().process_frame


## Feature 021: Mushroom Gremlins steal from the stash and run; caught,
## they drop the loot; escaped, it is gone.
func _check_mushroom_gremlin(player: Node3D) -> void:
	var spawner: Node = get_tree().get_first_node_in_group("mob_spawner")
	var gremlin_def: MobDefinition = spawner.get("sneak_definition")
	_check(gremlin_def != null and gremlin_def.steals_resources, "spawner has a thief (mushroom gremlin)")
	var wave: Array = spawner.build_wave(2)
	var first: int = wave.find(gremlin_def)
	_check(first >= 0 and first < wave.size() / 2, "night 2: the gremlin sneaks in early")

	# It steals the most plentiful resource from the campfire stash...
	for item in [&"wood", &"stone", &"berries", &"fiber", &"leaves", &"resin", &"clay", &"mushrooms", &"scrap", &"glow_shards"]:
		ResourceManager.spend(item, ResourceManager.get_count(item))
	ResourceManager.add(&"stone", 10)
	ResourceManager.add(&"wood", 3)
	player.global_position = Vector3(-12, 0, -8)  # out of the way
	var thief: Mob = _spawn_mob(gremlin_def, Vector3(0, 0, 12))
	var t: float = 0.0
	while int(thief.get("loot_amount")) == 0 and t < 15.0:
		await _wait(0.25)
		t += 0.25
	_check(thief.loot_id == &"stone" and thief.loot_amount == 4 and ResourceManager.get_count(&"stone") == 6,
		"gremlin stole 4 stone (%.1fs)" % t)
	_check(thief.is_fleeing and ResourceManager.get_count(&"wood") == 3, "it runs off and leaves the wood")
	# Feature 027: its own clips; it sneaks in and scurries off.
	var visual: CharacterVisual = thief.get_node("Visual") as CharacterVisual
	var anim_player: AnimationPlayer = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var missing: Array = []
	for state in visual.clips.keys():
		if not anim_player.has_animation(String(visual.clips[state])):
			missing.append(visual.clips[state])
	_check(missing.is_empty(), "gremlin model has all its clips %s" % [missing])
	_check(visual.current_move_clip() == StringName(visual.clips[&"flee"]),
		"a fleeing gremlin scurries (%s)" % visual.current_move_clip())
	# ...and drops it when caught.
	var at: Vector3 = thief.global_position
	thief.take_damage(999, player)
	await get_tree().process_frame
	var loot: Node3D = null
	for pickup in get_tree().get_nodes_in_group("pickups"):
		if pickup.get("item_id") == &"stone" and (pickup as Node3D).global_position.distance_to(Vector3(at.x, 0, at.z)) < 1.0:
			loot = pickup
	_check(loot != null and int(loot.get("amount")) == 4, "caught gremlin dropped its loot")
	if loot != null:
		player.global_position = loot.global_position
		await _wait(0.3)
		_check(ResourceManager.get_count(&"stone") == 10, "walking over the loot got it back")

	# An escaped gremlin keeps what it took.
	var lost_before: int = int(GameManager.stats.get(&"stolen_lost", 0))
	player.global_position = Vector3(-12, 0, -8)
	var runner: Mob = _spawn_mob(gremlin_def, Vector3(0, 0, 12))
	t = 0.0
	while is_instance_valid(runner) and t < 20.0:
		await _wait(0.25)
		t += 0.25
	_check(not is_instance_valid(runner) and int(GameManager.stats.get(&"stolen_lost", 0)) == lost_before + 4
		and ResourceManager.get_count(&"stone") == 6, "escaped gremlin got away with 4 stone (%.1fs)" % t)


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


## Feature 018: waves mix in Bramble Beasts, which go for buildings.
func _check_bramble_beast(player: Node3D) -> void:
	var spawner: Node = get_tree().get_first_node_in_group("mob_spawner")
	var beast_def: MobDefinition = spawner.get("heavy_definition")
	_check(beast_def != null and beast_def.prefers_buildings, "spawner has a siege mob (bramble beast)")
	for night in [1, 2, 3]:
		var wave: Array = spawner.build_wave(night)
		var beasts: int = wave.count(beast_def)
		var sneaks: int = wave.count(spawner.get("sneak_definition"))
		_check(beasts == spawner.get_heavy_count(night) and sneaks == spawner.get_sneak_count(night)
			and wave.size() == spawner.get_wave_size(night) + beasts + sneaks,
			"night %d wave: %d imps + %d beasts + %d gremlins" % [night, wave.size() - beasts - sneaks, beasts, sneaks])
		if beasts > 0:
			_check(wave.find(beast_def) >= wave.size() / 2 - 1, "night %d: beasts come in the second half" % night)

	# A beast walks past Leo to tear down the nearest fence, hitting hard.
	var fence_def: BuildingDefinition = BuildManager.get_definition(&"wooden_fence")
	var fence: Building = fence_def.get_scene().instantiate() as Building
	get_tree().current_scene.add_child(fence)
	fence.global_position = Vector3(-8, 0, 14)
	var beast: Mob = beast_def.get_scene().instantiate() as Mob
	get_tree().current_scene.add_child(beast)
	beast.global_position = Vector3(-8, 0, 17.5)
	player.global_position = Vector3(-11, 0, 16)
	player.call("stop_commands")
	var t: float = 0.0
	while fence.current_hp == fence_def.max_hp and t < 15.0:
		await _wait(0.25)
		t += 0.25
	var expected_hit: int = int(round(beast_def.attack_damage * beast_def.building_damage_multiplier))
	_check(fence_def.max_hp - fence.current_hp == expected_hit, "beast hit the fence for %d (%.1fs)" % [fence_def.max_hp - fence.current_hp, t])
	_check(beast.get("_chase_target") == null, "beast ignored Leo 3 m away")
	var knocked_from: Vector3 = beast.global_position
	beast.take_damage(1, player)
	await _wait(0.3)
	_check(beast.global_position.distance_to(knocked_from) < 0.25, "beast barely flinches from hits")

	# Feature 026: its own clips, and a telegraphed slam.
	var visual: CharacterVisual = beast.get_node("Visual") as CharacterVisual
	var player_anim: AnimationPlayer = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var missing: Array = []
	for state in visual.clips.keys():
		if not player_anim.has_animation(String(visual.clips[state])):
			missing.append(visual.clips[state])
	_check(missing.is_empty(), "beast model has all its clips %s" % [missing])
	# Hold the beast's own attacks so only the timed ones below land.
	beast.set("_attack_cooldown_remaining", 99.0)
	await _wait(1.0)
	beast.set("_attack_cooldown_remaining", 0.0)
	var before: int = fence.current_hp
	beast.call("_try_attack", fence)
	await _wait(beast_def.attack_hit_delay * 0.5)
	_check(fence.current_hp == before, "the slam has not landed during the windup")
	await _wait(beast_def.attack_hit_delay * 0.5 + 0.25)
	_check(fence.current_hp < before, "the slam lands at impact (%.2fs)" % beast_def.attack_hit_delay)
	# A kid who steps away during the windup is not hit.
	beast.set("_attack_cooldown_remaining", 99.0)
	await _wait(0.5)
	player.global_position = beast.global_position + Vector3(1.0, 0, 0)
	var leo_hp: int = player.get("current_hp")
	beast.set("_attack_cooldown_remaining", 0.0)
	beast.call("_try_attack", player)
	player.global_position = beast.global_position + Vector3(4.0, 0, 0)
	await _wait(beast_def.attack_hit_delay + 0.25)
	_check(int(player.get("current_hp")) == leo_hp, "Leo dodged the slam by stepping away")
	beast.take_damage(999, player)
	fence.queue_free()
	await _wait(0.2)


## Feature 023: actions layer over locomotion. While Leo runs, a swing
## plays on the upper body and the legs keep running; standing still it
## plays on the whole body.
func _check_animation_layers(player: Node3D) -> void:
	var visual: CharacterVisual = player.get_node("Visual") as CharacterVisual
	var tree: AnimationTree = visual.get_animation_tree()
	_check(tree != null and tree.active, "Leo has an active animation tree")
	player.command_move(player.global_position + Vector3(8, 0, 0))
	await _wait(0.4)
	_check(visual.is_moving() and float(tree.get("parameters/loco/blend_position")) > 1.0,
		"running blends the locomotion (%.1f)" % float(tree.get("parameters/loco/blend_position")))
	visual.play_action(&"attack", 1.9)
	await get_tree().physics_frame  # the tree updates on physics frames
	await get_tree().physics_frame
	_check(visual.active_action_layer() == "upper", "a swing while running plays on the upper body")
	player.stop_commands()
	await _wait(0.8)
	visual.play_action(&"attack", 1.9)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not visual.is_moving() and visual.active_action_layer() == "full", "a swing standing still plays on the whole body")
	await _wait(0.6)

	# Feature 024: footsteps, swaying foliage, day ambience.
	_check(visual.steps_puffed > 0, "running kicks up footstep dust (%d puffs)" % visual.steps_puffed)
	var tree_node: ResourceNode = _find_resource_node(&"wood")
	var swaying: bool = false
	for mesh in tree_node.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mesh as MeshInstance3D
		if m.mesh != null and m.get_surface_override_material(0) is ShaderMaterial:
			swaying = true
	_check(swaying, "trees use the swaying foliage material")
	var ambience: WorldAmbience = get_tree().current_scene.find_child("WorldAmbience", true, false) as WorldAmbience
	_check(ambience != null and ambience.leaves.emitting and not ambience.fireflies.emitting, "day: leaves drift, no fireflies")


func _recipe(id: StringName) -> CraftingRecipe:
	for recipe in CraftingManager.get_recipes():
		if recipe.id == id:
			return recipe
	return null


func _survive_night(night: int, player: Node3D) -> void:
	# Fast-forward: day -> sunset -> night.
	while TimeManager.current_phase != TimeManager.Phase.NIGHT:
		TimeManager.skip_phase()
	_check(AudioManager.mood == &"night", "night %d: night music mood" % night)
	var ambience: WorldAmbience = get_tree().current_scene.find_child("WorldAmbience", true, false) as WorldAmbience
	_check(ambience != null and ambience.fireflies.emitting and not ambience.leaves.emitting, "night %d: fireflies come out" % night)
	await _wait(0.2)
	_check(AudioManager.current_music() == AudioManager.library.music_night, "night %d: night track playing" % night)
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
	_check(not SaveManager.has_save(), "no save after a lost run")

	# Volume settings round-trip through user://settings.cfg.
	var saved_music: float = AudioManager.music_volume
	AudioManager.set_music_volume(0.35)
	var config: ConfigFile = ConfigFile.new()
	_check(config.load(AudioManager.SETTINGS_PATH) == OK and is_equal_approx(float(config.get_value("audio", "music")), 0.35),
		"music volume saved to settings.cfg")
	AudioManager.set_music_volume(saved_music)


## Feature 020: Continue rebuilds the camp from the night-1 autosave,
## and a 7-night run shows 7 moons and bigger waves.
func _run_continue_scenario() -> void:
	print("smoke: --- continue scenario ---")
	# Buildings from earlier checks live on the test root; clear them so
	# only the restored ones remain.
	for node in get_tree().get_nodes_in_group(Building.BUILDINGS_GROUP):
		node.queue_free()
	await get_tree().process_frame
	var data: Dictionary = _night1_save
	_check(not data.is_empty(), "have the night-1 save to continue")
	if data.is_empty():
		return
	# Damaged or foreign saves are refused.
	_check(SaveManager.parse("{not json").is_empty(), "a corrupt save is ignored")
	var old_version: Dictionary = data.duplicate(true)
	var text: String = SaveManager.serialize(old_version).replace('"version": 1', '"version": 99')
	_check(SaveManager.parse(text).is_empty(), "a save from another version is ignored")
	_check(SaveManager.parse(SaveManager.serialize(data)).hash() == SaveManager.parse(SaveManager.serialize(data)).hash()
		and not SaveManager.parse(SaveManager.serialize(data)).is_empty(), "save round-trips through JSON")

	GameManager.nights_to_win = int(data["nights_to_win"])
	GameManager.set("_pending_save", data)
	await _start_fresh_run()
	_check(TimeManager.day_number == 2 and TimeManager.current_phase == TimeManager.Phase.DAY, "continued at the morning of day 2")
	_check(ResourceManager.get_count(&"wood") == int(data["inventory"].get("wood", 0)), "inventory restored")
	var buildings: int = get_tree().get_nodes_in_group(Building.BUILDINGS_GROUP).size()
	_check(buildings == (data["buildings"] as Array).size(), "buildings restored (%d)" % buildings)
	var fire: BaseCore = _campfire()
	_check(fire.has_hearth == bool(data["campfire"]["hearth"]) and fire.current_hp == int(data["campfire"]["hp"]),
		"campfire restored (%d HP, hearth %s)" % [fire.current_hp, fire.has_hearth])
	var player: Node = get_tree().get_first_node_in_group("player")
	_check(ProgressionManager.get_xp(player) == int(data["player"]["xp"]) and bool(player.get("has_sturdy_stick")) == bool(data["player"]["stick"]),
		"Leo's progress restored (level %d)" % ProgressionManager.get_level(player))
	_check(int(GameManager.stats[&"nights_survived"]) == 1, "stats restored (1 night survived)")

	# A 7-night run.
	GameManager.nights_to_win = 7
	await _start_fresh_run()
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud == null:
		hud = _main.get_node_or_null("HUD")
	_check(hud != null and (hud.get("_moons") as Array).size() == 7, "7-night run shows 7 moons")
	var spawner: Node = get_tree().get_first_node_in_group("mob_spawner")
	_check(spawner.get_wave_size(7) == 19 and spawner.get_heavy_count(7) == 6, "night 7: 19 imps and 6 beasts")
	GameManager.nights_to_win = 3


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


## Waits `game_seconds` of game time at the test speed. It uses SPEED,
## not Engine.time_scale, which a hit-stop briefly lowers.
func _wait(game_seconds: float) -> void:
	await get_tree().create_timer(game_seconds / SPEED, true, false, true).timeout


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
