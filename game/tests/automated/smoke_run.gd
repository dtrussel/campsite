extends Node

## smoke_run.gd
##
## End-to-end headless smoke test for the playtest loop. Instances the
## real Main scene and drives it through a whole run:
##   gather -> craft a torch -> plant it -> survive 3 nights -> win,
## then a second run that loses when the campfire is destroyed, a
## continued run, and a run playing Nela with Leo as the companion.
## Features 035-036: the story cards and storybook, the shard drops and
## the Moon Lantern. Feature 038: the Moon-Eater, Chapter 2's last night.
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
const TEST_STORY_PATH: String = "user://smoke_story.cfg"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(TIMEOUT_SECONDS, true, false, true).timeout.connect(func() -> void:
		_fail("timed out after %ds" % TIMEOUT_SECONDS)
		_finish()
	)
	# Never touch a real player's autosave.
	SaveManager.set_save_path(TEST_SAVE_PATH)
	SaveManager.delete_save()
	StoryLibrary.progress_path = TEST_STORY_PATH
	StoryLibrary.forget_progress()
	await _run_story_scenario()
	await _run_win_scenario()
	await _run_loss_scenario()
	await _run_continue_scenario()
	await _run_hero_scenario()
	await _run_bark_scenario()
	await _run_boss_scenario()
	SaveManager.delete_save()
	StoryLibrary.forget_progress()
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
			var card: StoryCard = _main.get_node("HUD").call("story_card")
			_check(card != null and card.lines().size() == 2 and String(card.lines()[0]["speaker"]) == "leo"
				and String(card.lines()[0]["id"]).begins_with("dawn.c1.n1"), "dawn 1: Leo and Nela talk on the dawn card")
		if night < GameManager.nights_to_win:
			_check(GameManager.is_playing(), "still playing after night %d" % night)
	_check(GameManager.run_state == GameManager.RunState.WON, "run WON after %d nights" % GameManager.nights_to_win)
	# Feature 035: the Chapter 1 ending book comes before the stats.
	var end_root: Control = _main.get_node("EndScreen").get("_root")
	await get_tree().process_frame  # the book opens deferred
	var book: StoryBook = get_tree().get_first_node_in_group("story_book") as StoryBook
	_check(book != null and book.page_count() == 2 and not end_root.visible, "the Chapter 1 ending opens before the stats")
	if book != null:
		book.next()
		_check(book.page == 1, "the ending turns its page")
		book.next()
		await get_tree().process_frame
	_check(end_root.visible, "the stats show after the ending")
	_check(int(GameManager.stats[&"kills"]) > 0, "kills recorded (%d)" % GameManager.stats[&"kills"])
	_check(get_tree().paused, "world frozen behind end screen")
	_check(AudioManager.mood == &"", "music stops for the win stinger")
	_check(not SaveManager.has_save(), "a won run deletes its save")
	var shards_seen: int = ResourceManager.get_count(&"glow_shards") + get_tree().get_nodes_in_group("pickups").size()
	_check(shards_seen >= int(GameManager.stats[&"kills"]) / 3 - 1, "imps dropped glow shards (%d for %d kills)" % [shards_seen, GameManager.stats[&"kills"]])


## Feature 035: the story data, the intro storybook and the chapters;
## feature 036: shard drops and the Moon Lantern.
func _run_story_scenario() -> void:
	print("smoke: --- story scenario ---")
	_check(StoryLibrary.chapter_name(1) == "The Dark Moon" and StoryLibrary.chapter_name(2) == "Into the Hollow", "chapter names")
	GameManager.nights_to_win = 7
	_check(GameManager.chapter() == 2, "7 nights is Chapter 2")
	GameManager.nights_to_win = 3
	_check(GameManager.chapter() == 1, "3 nights is Chapter 1")
	var pages: Array = StoryLibrary.find(&"intro", 1)
	_check(pages.size() == 4 and (pages[0] as StoryBeat).page == 1 and (pages[0] as StoryBeat).painting != null,
		"the Chapter 1 intro has 4 painted pages, in order")
	var dawn: StoryBeat = StoryLibrary.first(&"dawn", 1, 1)
	_check(String(dawn.lines_for(&"leo")[0]["speaker"]) == "leo" and String(dawn.lines_for(&"nela")[0]["speaker"]) == "nela",
		"the played hero speaks first on the dawn card")
	var book: StoryBook = StoryBook.play(pages, &"leo")
	await get_tree().process_frame
	var turned: Array = [false]
	book.finished.connect(func() -> void: turned[0] = true)
	_check(book.page == 0, "the intro opens on page 1")
	book.next()
	_check(book.page == 1, "Space turns the page")
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(turned[0], "Esc skips the rest of the intro")
	_check(not StoryLibrary.has_seen("intro.c1"), "no intro marked seen yet")
	StoryLibrary.mark_seen("intro.c1")
	_check(StoryLibrary.has_seen("intro.c1") and not StoryLibrary.has_seen("intro.c2"), "the seen intro is remembered per chapter")
	StoryLibrary.forget_progress()

	# Shards: a chance per kill with pity, per mob type (seeded).
	var imp_def: MobDefinition = load("res://resources/mobs/shadow_imp.tres") as MobDefinition
	var beast_def: MobDefinition = load("res://resources/mobs/bramble_beast.tres") as MobDefinition
	GameManager.loot_misses = {}
	GameManager.loot_rng.seed = 36
	var hits: int = 0
	var longest_dry: int = 0
	var dry: int = 0
	for i in 100:
		if GameManager.roll_loot(imp_def):
			hits += 1
			dry = 0
		else:
			dry += 1
			longest_dry = maxi(longest_dry, dry)
	var beast_drops: int = 0
	for i in 10:
		beast_drops += 1 if GameManager.roll_loot(beast_def) else 0
	_check(beast_drops == 10, "every beast kill drops a shard")
	_check(hits >= 40 and hits <= 62, "100 imp kills drop %d shards (40-62)" % hits)
	_check(longest_dry < imp_def.drop_pity, "never more than %d imp kills in a row without a shard (%d)" % [imp_def.drop_pity - 1, longest_dry])
	GameManager.loot_misses = {}

	# The Moon Lantern by the tent.
	await _start_fresh_run()
	var lantern: MoonLantern = MoonLantern.find(get_tree())
	var player: Node3D = get_tree().get_first_node_in_group("player")
	_check(lantern != null and lantern.stage == 0 and lantern.max_stage() == 3 and lantern.radius() == 0.0,
		"the Moon Lantern stands dark by the tent (3 stages in Chapter 1)")
	player.global_position = lantern.global_position + Vector3(1.5, 0, 0)
	_check(not player.call("try_feed_lantern"), "nothing to hand over without shards")
	ResourceManager.add(&"glow_shards", 2)
	await get_tree().process_frame
	var card: StoryCard = _main.get_node("HUD").call("story_card")
	_check(card != null and String(card.lines()[0]["id"]) == "shard.leo", "the first shard of a run gets its story card")
	_check(player.call("try_feed_lantern") and lantern.stage == 1 and ResourceManager.get_count(&"glow_shards") == 0,
		"E by the lantern hands over the shards: stage 1")
	_check(is_equal_approx(lantern.radius(), lantern.min_radius), "stage 1 lights a %.1f m ring" % lantern.radius())
	var imp: Mob = _spawn_mob(imp_def, lantern.global_position + Vector3(2.5, 0, 0))
	imp.set_physics_process(false)
	await get_tree().process_frame
	_check(float(imp.call("_torch_slow_factor")) <= lantern.slow_factor, "an imp in the ring is slowed")
	var imp_hp: int = imp.current_hp
	await _wait(lantern.light_interval_seconds + 0.4)
	_check(imp.current_hp < imp_hp, "moonlight hurts the imp (%d -> %d)" % [imp_hp, imp.current_hp])
	imp.take_damage(999, player)
	ResourceManager.add(&"glow_shards", 10)
	var carried: int = ResourceManager.get_count(&"glow_shards")
	lantern.deliver(player)
	_check(lantern.is_full() and lantern.shards == lantern.shards_for_max()
		and ResourceManager.get_count(&"glow_shards") == carried - (lantern.shards_for_max() - 2),
		"the lantern takes only what it still needs (%d shards)" % lantern.shards)
	_check(is_equal_approx(lantern.radius(), lantern.max_radius), "fully lit: a %.1f m ring" % lantern.radius())
	var gremlin_def: MobDefinition = load("res://resources/mobs/mushroom_gremlin.tres") as MobDefinition
	var gremlin: Mob = _spawn_mob(gremlin_def, lantern.global_position + Vector3(6.0, 0, 0))
	await _wait(2.5)
	_check(not is_instance_valid(gremlin) or gremlin.is_fleeing and gremlin.loot_amount == 0, "a gremlin turns back at the bright ring")
	if is_instance_valid(gremlin):
		gremlin.take_damage(999, player)
	var data: Dictionary = SaveManager.snapshot()
	_check(int(data["lantern"]["shards"]) == lantern.shards, "the save holds the lantern's shards")
	var legacy: Dictionary = data.duplicate(true)
	legacy.erase("lantern")
	GameManager.set("_pending_save", SaveManager.parse(SaveManager.serialize(data)))
	await _start_fresh_run()
	lantern = MoonLantern.find(get_tree())
	_check(lantern.is_full(), "Continue keeps the lantern lit (stage %d)" % lantern.stage)
	GameManager.set("_pending_save", legacy)
	await _start_fresh_run()
	_check(MoonLantern.find(get_tree()).stage == 0, "older saves start the lantern dark")
	GameManager.nights_to_win = 7
	await _start_fresh_run()
	_check(MoonLantern.find(get_tree()).max_stage() == 6, "Chapter 2's lantern has 6 stages")
	GameManager.nights_to_win = 3

	# Feature 043: Mum's portraits, her walk home, and her seat at the title.
	_check(StoryLibrary.speaker_portrait("mum", "worried").resource_path.ends_with("mum_worried.png")
		and StoryLibrary.speaker_portrait("mum").resource_path.ends_with("mum.png")
		and StoryLibrary.speaker_portrait("mum", "nope").resource_path.ends_with("mum.png"), "Mum's expressions, with a fallback")
	var hero: Node3D = get_tree().get_first_node_in_group("player")
	get_tree().paused = true  # as behind the end screen
	var arrival: MumArrival = MumArrival.play(get_tree().current_scene, hero.global_position)
	await get_tree().process_frame
	var model: Node = arrival.visual.get_child(0) if arrival.visual.get_child_count() > 0 else null
	_check(model != null and model.find_child("AnimationPlayer", true, false) != null, "Mum's model loads, with its clips")
	var player_anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer if model != null else null
	_check(player_anim != null and player_anim.has_animation("Wave") and player_anim.has_animation("Walking_A"),
		"Mum can walk and wave")
	var gap: float = arrival.global_position.distance_to(arrival.target)
	await _wait(1.2)
	_check(arrival.global_position.distance_to(arrival.target) < gap - 0.5, "Mum walks to the kids while the world is paused")
	var arrived: Array = [false]
	arrival.finished.connect(func() -> void: arrived[0] = true)
	arrival.finish()
	_check(arrived[0] and arrival.global_position.distance_to(arrival.target) < 0.01, "skipping puts Mum by the kids")
	get_tree().paused = false
	var backdrop: GDScript = load("res://scripts/ui/title_backdrop.gd")
	_check(not backdrop.call("mum_is_home"), "Mum isn't home before the true ending")
	StoryLibrary.mark_seen(StoryLibrary.TRUE_ENDING)
	_check(backdrop.call("mum_is_home"), "after the true ending Mum sits by the title fire")
	StoryLibrary.forget_progress()


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
	# Feature 028: the Shadow Imp has its own clips.
	var imp: Mob = _spawn_mob(spawner.get("mob_definition"), Vector3(-14, 0, 18))
	await get_tree().process_frame
	var imp_visual: CharacterVisual = imp.get_node("Visual") as CharacterVisual
	var imp_player: AnimationPlayer = imp_visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var imp_missing: Array = []
	for state in imp_visual.clips.keys():
		if not imp_player.has_animation(String(imp_visual.clips[state])):
			imp_missing.append(imp_visual.clips[state])
	_check(imp_missing.is_empty(), "imp model has all its clips %s" % [imp_missing])
	# Defeated with no attacker (so no XP for Leo): it tumbles over and its
	# corpse is gone within CORPSE_SECONDS.
	imp.take_damage(999, null)
	await _wait(2.0)
	_check(not is_instance_valid(imp), "a defeated imp's corpse is cleared")
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
		var leaf: ShaderMaterial = m.get_surface_override_material(0) as ShaderMaterial if m.mesh != null else null
		if leaf != null and leaf.shader == Stylize.FOLIAGE_SHADER:
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
	var end_screen: Node = _main.get_node("EndScreen")
	_check(String(end_screen.call("story_text")).begins_with("The dark came in") and (end_screen.get("_root") as Control).visible,
		"the defeat says why: %s" % end_screen.call("story_text"))
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
	_check(ProgressionManager.get_xp(player) == int(data["player"]["xp"]) and bool(player.get("has_signature")) == bool(data["player"]["signature"]),
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


## Feature 034: the hero select screen, and a run playing Nela. Each
## hero keeps their style in either role and their signature craft.
func _run_hero_scenario() -> void:
	print("smoke: --- hero scenario ---")
	var screen: Node = (load("res://scenes/ui/HeroSelect.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	_check(int(screen.get("selected")) == 0 and (screen.call("selected_hero") as HeroDefinition).id == &"leo",
		"hero select opens on the last pick (Leo)")
	screen.call("select", 1)
	_check((screen.call("selected_hero") as HeroDefinition).id == &"nela", "hero select picks Nela")
	screen.call("select", HeroRoster.all().size())
	_check(int(screen.get("selected")) == 0, "hero select wraps around the roster")
	screen.queue_free()
	await get_tree().process_frame

	GameManager.set_party(&"nela")
	_check(GameManager.companion_id == &"leo", "Leo comes along when Nela is played")
	await _start_fresh_run()
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var companion: Node3D = get_tree().get_first_node_in_group("companions")
	_check(player.is_in_group(HeroRoster.group_for(&"nela")) and companion.is_in_group(HeroRoster.group_for(&"leo")),
		"the player is Nela and the companion is Leo")
	var nela: HeroDefinition = HeroRoster.get_hero(&"nela")
	var visual: CharacterVisual = player.get_node("Visual") as CharacterVisual
	_check(visual.model_scene == nela.model_scene and int(player.get("max_hp")) == nela.stats.base_max_health,
		"the player has Nela's body and health (%d HP)" % int(player.get("max_hp")))
	_check(float(player.get("attack_range")) > 4.0 and float(companion.call("get_attack_range")) <= 2.0,
		"Nela shoots from range; Leo fights up close")
	var hud: Node = _main.get_node_or_null("HUD")
	var portrait: HudWidgets.Portrait = hud.get("_hero_portrait") if hud != null else null
	_check(portrait != null and portrait.texture == nela.portrait, "the HUD shows Nela in the hero bar")

	# A pebble flies and hits an imp a few metres away.
	var spawner: Node = get_tree().get_first_node_in_group("mob_spawner")
	var imp: Mob = _spawn_mob(spawner.get("mob_definition"), player.global_position + Vector3(3.5, 0, 0))
	await get_tree().process_frame
	var imp_hp: int = imp.current_hp
	player.call("_perform_attack", imp)
	_check(imp.current_hp == imp_hp, "the pebble has not landed yet")
	await _wait(PebbleShot.FLIGHT_SECONDS + 0.2)
	_check(not is_instance_valid(imp) or imp.current_hp < imp_hp, "Nela's pebble hit the imp 3.5 m away")
	if is_instance_valid(imp):
		imp.take_damage(999, player)

	# The signature crafts follow the hero, not the role.
	for item in [&"wood", &"scrap", &"resin", &"fiber"]:
		ResourceManager.add(item, 10)
	var table: Building = _spawn_building(&"crafting_table", Vector3(5, 0, -6))
	var reach: float = float(player.get("attack_range"))
	_check(CraftingManager.craft(_recipe(&"slingshot"), player)
		and is_equal_approx(float(player.get("attack_range")), reach * nela.signature_range_factor), "the slingshot goes to Nela (the player)")
	var damage: int = int(companion.get("_current_attack_damage"))
	_check(CraftingManager.craft(_recipe(&"sturdy_stick"), player)
		and int(companion.get("_current_attack_damage")) == damage + 2, "the sturdy stick goes to Leo (the companion)")

	# The save remembers the party; Continue plays Nela again.
	var data: Dictionary = SaveManager.snapshot()
	_check(String(data["party"]["hero"]) == "nela" and String(data["party"]["companion"]) == "leo", "the save holds the party")
	var legacy: Dictionary = data.duplicate(true)
	legacy.erase("party")
	_check(SaveManager.party_of(legacy)["hero"] == &"leo", "older saves without a party are Leo with Nela")
	table.queue_free()
	GameManager.set_party(&"leo")
	var party: Dictionary = SaveManager.party_of(SaveManager.parse(SaveManager.serialize(data)))
	GameManager.set_party(party["hero"], party["companion"])
	GameManager.set("_pending_save", data)
	await _start_fresh_run()
	player = get_tree().get_first_node_in_group("player")
	_check(player.is_in_group(HeroRoster.group_for(&"nela")) and bool(player.get("has_signature")),
		"continued as Nela, slingshot and all")
	GameManager.set_party(&"leo")


## Feature 037: the siblings' barks. The right hero speaks, keyed by who
## is played; cooldowns hold back spam; a bark never cuts off a story
## voice; the companion warns about a mob behind the player.
func _run_bark_scenario() -> void:
	print("smoke: --- bark scenario ---")
	GameManager.set_party(&"leo")
	await _start_fresh_run()
	var director: BarkDirector = get_tree().get_first_node_in_group("bark_director") as BarkDirector
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var companion: Node3D = get_tree().get_first_node_in_group("companions")
	_check(director != null, "the run has a bark director")
	var max_hp: int = int(companion.get("max_hp"))
	companion.call("take_damage", max_hp - int(max_hp * 0.2))
	var bubble: SpeechBubble = SpeechBubble.on(companion)
	_check(bubble != null and _bark_line(bubble.text, &"low_hp", &"nela"), "Nela at low HP says so over her head")
	_check(SpeechBubble.on(player) == null, "the player stays quiet")
	_check(not director.bark(&"low_hp", companion), "low HP again within its cooldown: no bark")
	_check(not director.bark(&"thief"), "a second bark right away waits for the shared cooldown")
	director.clock += BarkDirector.GLOBAL_COOLDOWN + 1.0
	_check(director.bark(&"thief"), "a gremlin steals: the siblings shout")
	_check(_bark_line(SpeechBubble.on(player).text, &"thief", &"leo"), "Leo (played) calls out first")
	await _wait(BarkDirector.REPLY_DELAY + 1.0)
	_check(SpeechBubble.on(companion) != null and _bark_line(SpeechBubble.on(companion).text, &"thief", &"nela"),
		"Nela replies")
	_check(SpeechBubble.on(companion).position.y > float(companion.get("_hp_bar").position.y),
		"the bubble sits above the health bar")

	# A story line keeps speaking under a bark.
	var story_voice: AudioStream = load("res://assets/audio/sfx/chirp_nela_1.ogg")
	AudioManager.play_voice(story_voice)
	ProgressionManager.level_up.emit(player, 2)
	_check(_bark_line(SpeechBubble.on(player).text, &"level_up", &"leo"), "a level-up is cheered by that hero")
	_check(AudioManager.play_bark(null, "leo") == 0.0, "no bark audio while a story line speaks")
	AudioManager.stop_voice()
	_check(AudioManager.play_bark(null, "leo") > 0.0, "the bark chirps when the story is quiet")

	# Danger behind the player: the companion warns.
	director.clock += 30.0
	var imp_def: MobDefinition = get_tree().get_first_node_in_group("mob_spawner").get("mob_definition")
	var facing: Vector3 = player.call("get_facing")
	var imp: Mob = _spawn_mob(imp_def, player.global_position - facing * 3.0)
	await get_tree().process_frame
	_check(director.danger_behind(), "an imp 3 m behind the player counts as danger")
	await _wait(BarkDirector.DANGER_POLL_SECONDS + 0.3)
	_check(SpeechBubble.on(companion) != null and _bark_line(SpeechBubble.on(companion).text, &"danger_behind", &"nela"),
		"Nela warns: behind you!")
	director.clock += 30.0
	companion.call("take_damage", 9999)
	_check(_bark_line(SpeechBubble.on(player).text, &"companion_down", &"leo"), "Leo calls out when Nela is knocked out")
	director.clock += 30.0
	_check(not director.bark(&"danger_behind"), "a knocked-out companion gives no warnings")
	imp.take_damage(999, player)

	# Nela played: the speakers swap, and the events reach the director.
	GameManager.set_party(&"nela")
	await _start_fresh_run()
	director = get_tree().get_first_node_in_group("bark_director") as BarkDirector
	player = get_tree().get_first_node_in_group("player")
	companion = get_tree().get_first_node_in_group("companions")
	var gremlin_def: MobDefinition = load("res://resources/mobs/mushroom_gremlin.tres")
	var gremlin: Mob = _spawn_mob(gremlin_def, player.global_position + Vector3(8, 0, 8))
	await get_tree().process_frame
	gremlin.stole.emit(gremlin, &"wood", 2)
	_check(SpeechBubble.on(player) != null and _bark_line(SpeechBubble.on(player).text, &"thief", &"nela"),
		"Nela played: she shouts at the thief first")
	await _wait(BarkDirector.REPLY_DELAY + 1.0)
	_check(SpeechBubble.on(companion) != null and _bark_line(SpeechBubble.on(companion).text, &"thief", &"leo"),
		"and Leo replies")
	gremlin.take_damage(999, player)
	director.clock += 30.0
	var beast: Mob = _spawn_mob(load("res://resources/mobs/bramble_beast.tres"), player.global_position + Vector3(10, 0, -8))
	await get_tree().process_frame
	_check(_bark_line(SpeechBubble.on(player).text, &"first_beast", &"nela"), "the first beast of the night gets a shout")
	director.clock += 30.0
	_check(not director.bark(&"first_beast"), "only once a night")
	beast.take_damage(9999, player)
	GameManager.set_party(&"leo")


## Feature 038: the Moon-Eater. Its eyes watch on night 5; on night 7 it
## rises with a boss bar and holds the night; its stomp can be dodged;
## summons respect the mob cap and put out torches; scripted damage
## takes it through every phase, including a reach that runs out of
## time; calmed, it shrinks by the fire and the true ending plays.
func _run_boss_scenario() -> void:
	print("smoke: --- boss scenario ---")
	GameManager.set_party(&"leo")
	GameManager.nights_to_win = 7
	await _start_fresh_run()
	var spawner: MobSpawner = get_tree().get_first_node_in_group("mob_spawner") as MobSpawner
	_check(spawner.is_boss_night(7) and not spawner.is_boss_night(6), "the Moon-Eater comes on Chapter 2's last night")
	var wave: Array[MobDefinition] = spawner.build_wave(7)
	_check(wave[0].is_boss and wave.size() == 1 + spawner.boss_escort, "night 7 is the boss and %d imps" % spawner.boss_escort)
	GameManager.nights_to_win = 3
	_check(not spawner.is_boss_night(3), "no boss in Chapter 1")
	GameManager.nights_to_win = 7

	# Night 5: its eyes at the treeline, gone at dawn.
	TimeManager.day_number = 5
	while not TimeManager.is_night():
		TimeManager.skip_phase()
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("moon_eater_eyes").size() == 1, "night 5: its eyes watch from the treeline")
	TimeManager.skip_phase()
	await _wait(2.0)
	_check(get_tree().get_nodes_in_group("moon_eater_eyes").is_empty(), "the eyes fade at dawn")

	# Night 7, with the lantern fully lit.
	var lantern: MoonLantern = MoonLantern.find(get_tree())
	lantern.restore(lantern.shards_for_max())
	TimeManager.day_number = 6
	while not TimeManager.is_night():
		TimeManager.skip_phase()
	var boss: BossController = null
	var t: float = 0.0
	while t < 8.0:
		boss = BossController.find(get_tree())
		if boss != null and boss.phase != BossController.Phase.RISING:
			break
		await _wait(0.25)
		t += 0.25
	_check(boss != null and boss.phase == BossController.Phase.STOMPING, "night 7: the Moon-Eater rises (%.1fs)" % t)
	if boss == null:
		GameManager.nights_to_win = 3
		return
	boss.set_physics_process(false)  # the test drives it from here
	var hud: Node = _main.get_node("HUD")
	_check(hud.call("boss_bar_visible"), "the boss bar shows")
	_check(AudioManager.mood == &"boss", "the boss music plays")
	TimeManager.remaining_seconds = 0.01
	await _wait(0.3)
	_check(TimeManager.is_night() and TimeManager.hold_night, "the night holds while it stands")
	while int(spawner.get("_remaining_to_spawn")) > 0:
		await _wait(0.5)
	_clear_mobs_except(boss)

	# The stomp: a ring with time to step out of it.
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var forward: Vector3 = boss.call("_forward")
	var ring: Vector3 = boss.global_position + forward * boss.stomp_reach
	_check(boss.stomp_windup >= 0.6, "the stomp gives %.1fs to step away" % boss.stomp_windup)
	player.global_position = ring
	var hp: int = int(player.get("current_hp"))
	boss.stomp()
	await get_tree().process_frame
	_check(_telegraphs() > 0, "the stomp draws its ring on the ground")
	await _wait(0.3)
	player.global_position = ring - forward * (boss.stomp_radius + 6.0)
	await _wait(boss.stomp_windup)
	_check(int(player.get("current_hp")) == hp, "stepping out of the ring dodges the stomp")
	player.global_position = ring
	boss.stomp()
	await _wait(boss.stomp_windup + 0.3)
	_check(int(player.get("current_hp")) < hp, "staying in the ring gets stomped (%d -> %d)" % [hp, int(player.get("current_hp"))])
	player.global_position = Vector3(3, 0, 6)
	_check(Telegraph.in_area(boss.global_position, 0.0, 5.0, 140.0, boss.global_position + Vector3(0, 0, 3))
		and not Telegraph.in_area(boss.global_position, 0.0, 5.0, 140.0, boss.global_position + Vector3(0, 0, -3)),
		"the sweep hits the slice in front, not behind")

	# Phase 2: summons, under the mob cap, and the torches go out.
	boss.take_damage(int(boss.max_hp() * 0.42), player)
	_check(boss.phase == BossController.Phase.SUMMONING, "below 60%%: it starts summoning (%d HP)" % boss.current_hp)
	_clear_mobs_except(boss)
	var torch: Node3D = (load("res://scenes/buildings/Torch.tscn") as PackedScene).instantiate() as Node3D
	get_tree().current_scene.add_child(torch)
	torch.global_position = Vector3(-3, 0, 3)
	var came: int = boss.summon()
	_check(came == boss.summon_pack, "it summons a pack of %d imps" % came)
	_check(not torch.call("affects", torch.global_position), "the summon puts out the torches")
	var imp_def: MobDefinition = spawner.mob_definition
	while get_tree().get_nodes_in_group("mobs").size() < spawner.mob_cap - 1:
		_spawn_mob(imp_def, Vector3(randf_range(-12, 12), 0, -14))
	await get_tree().process_frame
	boss.summon()
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("mobs").size() <= spawner.mob_cap,
		"summons respect the mob cap (%d of %d)" % [get_tree().get_nodes_in_group("mobs").size(), spawner.mob_cap])
	_clear_mobs_except(boss)

	# Phase 3: it reaches for the lantern; the lantern stage sets the time.
	boss.take_damage(boss.current_hp - int(boss.max_hp() * 0.2), player)
	_check(boss.phase == BossController.Phase.REACHING, "below 25%: it goes for the Moon Lantern")
	boss.global_position = lantern.global_position + Vector3(2.0, 0, 0)
	boss.set_physics_process(true)
	t = 0.0
	while not boss.is_draining() and t < 6.0:
		await _wait(0.25)
		t += 0.25
	_check(boss.is_draining() and is_equal_approx(float(boss.get("_reach_total")), boss.reach_seconds(6)),
		"it holds the lantern: the kids have %.0fs with a full lantern" % float(boss.get("_reach_total")))
	_check(boss.reach_seconds(3) < boss.reach_seconds(6), "a half lantern gives less time")
	var reach_hp: int = boss.current_hp
	boss.take_damage(10, player)
	_check(reach_hp - boss.current_hp == 5, "hits do half damage while it curls round the lantern")
	boss.set("_reach_left", 0.01)
	await _wait(0.2)
	_check(lantern.stage == 4 and boss.phase == BossController.Phase.SUMMONING,
		"too slow: it swallows two stages (lantern %d/6)" % lantern.stage)
	_check(is_equal_approx(boss.hp_ratio(), boss.reach_heal_to), "and heals to %.0f%%" % (boss.hp_ratio() * 100.0))
	boss.set_physics_process(false)

	# Calmed: it lets the moon go, shrinks by the fire, and dawn comes.
	var imp: Mob = _spawn_mob(imp_def, Vector3(10, 0, 10))
	await get_tree().process_frame
	var fell_at: Vector3 = boss.global_position
	boss.take_damage(99999, player)
	_check(boss.phase == BossController.Phase.CALMED and not boss.is_in_group("mobs"), "at 0 HP it is calmed, not killed")
	_check(not is_instance_valid(imp) or imp.current_hp <= 0, "every other shadow fades with it")
	t = 0.0
	while GameManager.is_playing() and t < 20.0:
		await _wait(0.25)
		t += 0.25
	_check(GameManager.run_state == GameManager.RunState.WON and GameManager.end_reason == "You calmed the Moon-Eater!",
		"the moon comes back at dawn: the run is won (%.1fs)" % t)
	_check(int(GameManager.stats.get(&"boss_calmed", 0)) == 1, "the calm is counted")
	_check(is_instance_valid(boss) and boss.global_position.distance_to(_campfire().global_position) < 3.0,
		"a small warm golem curls up by the fire")
	var pile: Node3D = get_tree().get_first_node_in_group(MoonEaterVisual.PILE_GROUP) as Node3D
	_check(pile != null and pile.get_child_count() >= 10 and pile.get_child(0).global_position.distance_to(fell_at) < 2.5,
		"it fell apart into a heap of planks and stones where it stood")
	_check(not hud.call("boss_bar_visible"), "the boss bar is gone")
	await get_tree().process_frame
	var mums: Array = get_tree().get_nodes_in_group("mum")  # the story scenario left one too
	var arrival: MumArrival = mums.back() as MumArrival if not mums.is_empty() else null
	_check(arrival != null, "then Mum walks out of the woods")
	if arrival != null:
		arrival.finish()
	var book: StoryBook = null
	for i in 30:
		await get_tree().process_frame
		book = get_tree().get_first_node_in_group("story_book") as StoryBook
		if book != null:
			break
	_check(book != null and book.page_count() == 2, "and the true ending opens")
	if book != null:
		book.next()
		book.next()
		await get_tree().process_frame
	StoryLibrary.forget_progress()
	GameManager.nights_to_win = 3


func _clear_mobs_except(keep: Node) -> void:
	for node in get_tree().get_nodes_in_group("mobs"):
		if node != keep:
			(node as Mob).take_damage(9999, null)


func _telegraphs() -> int:
	var count: int = 0
	for node in get_tree().current_scene.get_children():
		if node is Telegraph:
			count += 1
	return count


func _bark_line(text: String, trigger: StringName, speaker: StringName) -> bool:
	for line in BarkLibrary.lines_for(trigger, speaker, GameManager.hero_id):
		if String((line as Dictionary).get("text", "")) == text:
			return true
	return false


func _start_fresh_run() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if _main != null:
		# Wait until the old camp is really gone: resuming from a physics-
		# frame timer, one process frame can still run before it is freed.
		var old: Node = _main
		old.queue_free()
		while is_instance_valid(old):
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
