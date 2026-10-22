extends "res://tests/automated/smoke_scenario.gd"

## The run session: a save from before it, the autoloads and the world
## saving themselves, and an in-place reset.


## A save written by a build from before the run session (VERSION 2).
const OLD_SAVE_FIXTURE: String = "res://tests/fixtures/save_v2_day1.json"


func run() -> void:
	await _run_old_save_scenario()
	await _run_autoload_save_scenario()
	await _run_world_save_scenario()
	await _run_reset_scenario()


## A save written before the run session (VERSION 2,
## checked in as a fixture) still continues with every field intact: the
## camp, the heroes, their perks, the lantern and an Ember Heart torch.
func _run_old_save_scenario() -> void:
	print("smoke: --- old save scenario ---")
	var data: Dictionary = SaveManager.parse(FileAccess.get_file_as_string(OLD_SAVE_FIXTURE))
	_check(not data.is_empty(), "the old-format save fixture parses")
	if data.is_empty():
		return
	# Only the save's buildings and torches may stand on the test root.
	for node in get_tree().get_nodes_in_group(Building.BUILDINGS_GROUP) + get_tree().get_nodes_in_group("torches"):
		node.queue_free()
	await get_tree().process_frame
	var finished: Array[int] = []
	var on_finished: Callable = func() -> void: finished.append(TimeManager.day_number)
	RunSession.restore_finished.connect(on_finished)
	GameManager.set_party(&"nela")  # the save's party wins
	GameManager.nights_to_win = 7
	await _continue_from(data)
	RunSession.restore_finished.disconnect(on_finished)
	var player: Hero = get_tree().get_first_node_in_group("player") as Hero
	var companion: Hero = get_tree().get_first_node_in_group("companions") as Hero
	for hero in [player, companion]:
		(hero as Node).set_physics_process(false)  # leave the blueprint half built
	# The snapshot first, before anything in the camp moves.
	var again: Dictionary = SaveManager.parse(SaveManager.serialize(RunSession.snapshot()))
	_check(finished == [int(data["day"]) + 1], "the run session announces the finished restore once (%s)" % [finished])
	_check(GameManager.is_playing() and TimeManager.day_number == int(data["day"]) + 1
		and TimeManager.current_phase == TimeManager.Phase.DAY and GameManager.nights_to_win == int(data["nights_to_win"]),
		"continued at the morning of day %d of %d" % [TimeManager.day_number, GameManager.nights_to_win])
	var inventory: Dictionary = data["inventory"]
	var counts_match: bool = true
	for definition in ResourceManager.get_definitions():
		counts_match = counts_match and ResourceManager.get_count(definition.id) == int(inventory.get(String(definition.id), 0))
	_check(counts_match, "the inventory comes back (%s)" % [inventory])
	var fire: BaseCore = _campfire()
	_check(fire.current_hp == int(data["campfire"]["hp"]) and fire.has_hearth == bool(data["campfire"]["hearth"]),
		"the campfire comes back (%d HP, hearth)" % fire.current_hp)
	var built: Building = null
	var blueprint: Building = null
	for node in get_tree().get_nodes_in_group(Building.BUILDINGS_GROUP):
		var building: Building = node as Building
		if building.definition.id == &"wooden_fence":
			built = building
		elif building.definition.id == &"watch_post":
			blueprint = building
	var fence_entry: Dictionary = data["buildings"][0]
	var post_entry: Dictionary = data["buildings"][1]
	_check(get_tree().get_nodes_in_group(Building.BUILDINGS_GROUP).size() == 2 and built != null and built.is_built()
		and built.current_hp == int(fence_entry["hp"]) and absf(built.global_rotation.y - float(fence_entry["yaw"])) < 0.01
		and built.global_position.distance_to(Vector3(6, 0, 4)) < 0.01,
		"the built fence comes back where it stood (%d HP)" % (built.current_hp if built != null else -1))
	_check(blueprint != null and blueprint.is_blueprint() and is_equal_approx(blueprint.build_progress, float(post_entry["progress"]))
		and blueprint.current_hp == int(post_entry["hp"]) and blueprint.global_position.distance_to(Vector3(-5, 0, 6)) < 0.01,
		"the half-built watch post comes back as a blueprint at 50%")
	_check(GameManager.hero_id == &"leo" and GameManager.companion_id == &"nela"
		and player.is_in_group(HeroRoster.group_for(&"leo")), "the party comes back: Leo plays, Nela tags along")
	_check(ProgressionManager.get_xp(player) == int(data["player"]["xp"]) and player.tool_tier == 1
		and PerkManager.perks_of(player) == [&"ember_heart"], "Leo's XP, sturdy stick and Ember Heart come back")
	_check(ProgressionManager.get_xp(companion) == int(data["sibling"]["xp"]) and not companion.has_signature
		and PerkManager.perks_of(companion) == [&"quick_hands"]
		and int(companion.get("current_task")) == int(data["sibling"]["task"]), "Nela's XP, Quick Hands and task come back")
	_check(not PerkManager.is_picking(), "no card is owed, so no picker opens")
	var stats_match: bool = true
	for key in (data["stats"] as Dictionary).keys():
		stats_match = stats_match and int(GameManager.stats.get(StringName(key), -1)) == int(data["stats"][key])
	_check(stats_match, "the run stats come back")
	_check(MoonLantern.find(get_tree()).shards == int(data["lantern"]["shards"]), "the Moon Lantern keeps its shards")
	var torch_entry: Dictionary = data["torches"][0]
	var torch: Node3D = null
	for node in get_tree().get_nodes_in_group("torches"):
		if (node as Node3D).global_position.distance_to(Vector3(3, 0, -2)) < 0.01:
			torch = node as Node3D
	_check(torch != null and int(torch.get("dawns_to_burn")) == int(torch_entry["dawns"])
		and is_equal_approx(float(torch.get("radius")), float(torch_entry["radius"])),
		"the Ember Heart torch comes back with its dawn left and its %.1f m ring" % float(torch_entry["radius"]))
	# Saved again, every field of the old save is still there (a hero's
	# `signature` flag is saved as its `tier`). Stats added since start
	# fresh beside the old ones.
	var lost: Array[String] = []
	for key in data.keys():
		var expected: Variant = int(data["day"]) + 1 if key == "day" else data[key]
		if expected is Dictionary and (expected as Dictionary).has("signature"):
			expected = (expected as Dictionary).duplicate(true)
			expected["tier"] = 1.0 if bool(expected["signature"]) else 0.0  # JSON numbers are floats
			expected.erase("signature")
		var kept: Variant = again.get(key)
		if key == "stats" and kept is Dictionary:
			for stat in (data["stats"] as Dictionary).keys():
				if (kept as Dictionary).get(stat) != data["stats"][stat]:
					lost.append("stats.%s" % stat)
		elif not again.has(key) or kept != expected:
			lost.append(key)
	_check(lost.is_empty(), "saving the continued run keeps every field of the old save (changed: %s)" % [lost])
	for node in get_tree().get_nodes_in_group(Building.BUILDINGS_GROUP) + get_tree().get_nodes_in_group("torches"):
		node.queue_free()


## The autoloads save themselves. A level-up just
## before the dawn autosave still gives its card after Continue, the
## shard pity counter survives Continue, and a new run starts with no
## perk timer, deal, crafting state or loot rolls left from the last.
func _run_autoload_save_scenario() -> void:
	print("smoke: --- autoload save scenario ---")
	await _start_fresh_run(_config(5.0))  # the level-up opens the picker
	var player: Hero = Party.player_hero()
	var companion: Hero = Party.companion()
	companion.set_physics_process(false)  # no kill moves the pity counter
	ProgressionManager.award_xp(player, ProgressionManager.get_xp_to_next_level(player), &"test")
	_check(PerkManager.is_picking() and PerkManager.perks_of(player).is_empty(), "a level-up at dusk opens the picker")
	GameManager.loot_misses = {&"shadow_imp": 3, &"mushroom_gremlin": 1}
	var at_save: Dictionary = {}
	var on_saved: Callable = func(day: int) -> void:
		at_save.merge({"day": day, "level": ProgressionManager.get_level(player), "misses": GameManager.loot_misses.duplicate()})
	SaveManager.saved.connect(on_saved)
	for i in 3:  # day -> sunset -> night -> dawn: the autosave
		TimeManager.skip_phase()
	await get_tree().process_frame
	await get_tree().process_frame
	SaveManager.saved.disconnect(on_saved)
	var data: Dictionary = SaveManager.load_save()
	_check(not at_save.is_empty() and not data.is_empty() and int(data["day"]) == 1,
		"the dawn autosave is written with the card still owed (level %s)" % at_save.get("level", "?"))
	if data.is_empty() or at_save.is_empty():
		return
	await _continue_from(data)
	await get_tree().process_frame
	player = Party.player_hero()
	_check(ProgressionManager.get_level(player) == int(at_save["level"]) and int(at_save["level"]) >= 2
		and PerkManager.perks_of(player).size() == ProgressionManager.get_level(player) - 1,
		"after Continue the level-up still gives its card (level %d, %d cards)" % [ProgressionManager.get_level(player), PerkManager.perks_of(player).size()])
	_check(GameManager.loot_misses == at_save["misses"], "the shard pity counter survives Continue (%s)" % [GameManager.loot_misses])

	# Leftovers from this run's perks and crafting.
	PerkManager.take(player, &"stand_firm")
	PerkManager.clock = 999.0
	CraftingManager.is_crafting = true
	for i in 5:
		PerkManager.rng.randi()
		GameManager.loot_rng.randi()
	await _start_fresh_run(_config(0.0, 7, 8))
	player = Party.player_hero()
	var deal: RandomNumberGenerator = RandomNumberGenerator.new()
	deal.seed = 7
	var loot: RandomNumberGenerator = RandomNumberGenerator.new()
	loot.seed = 8
	_check(PerkManager.perks_of(player).is_empty() and PerkManager.perks_of(Party.companion()).is_empty()
		and not PerkManager.is_picking(), "a new run starts with no perks")
	_check(PerkManager.clock < 5.0, "the perk clock starts again (%.1f s)" % PerkManager.clock)
	_check(PerkManager.rng.state == deal.state and GameManager.loot_rng.state == loot.state,
		"the perk deal and the loot rolls start from the new run's seeds")
	_check(not CraftingManager.is_crafting and GameManager.loot_misses.is_empty(), "no crafting state or pity counter carries over")


## The world saves itself. The campfire, a built
## fence, a half-built watch post, a paid-for blueprint, an Ember Heart
## torch, the Moon Lantern and both heroes go through save and Continue;
## each comes back as it was, HP bars included, and a save without a
## blueprint's paid cost (before perk cards) refunds today's price.
func _run_world_save_scenario() -> void:
	print("smoke: --- world save scenario ---")
	await _start_fresh_run()
	var player: Hero = get_tree().get_first_node_in_group("player") as Hero
	var companion: Companion = get_tree().get_first_node_in_group("companions") as Companion
	for hero in [player, companion]:
		(hero as Node).set_physics_process(false)  # nobody hammers or wanders
	var fire: BaseCore = _campfire()
	fire.build_hearth()
	fire.take_damage(60)
	var fence_def: BuildingDefinition = BuildManager.get_definition(&"wooden_fence")
	var post_def: BuildingDefinition = BuildManager.get_definition(&"watch_post")
	var base: Vector3 = fire.global_position
	var fence: Building = BuildManager.place_blueprint(fence_def, Transform3D(Basis(Vector3.UP, 0.3), base + Vector3(7, 0, 3)))
	fence.complete_construction(player)
	fence.take_damage(5)
	var post: Building = BuildManager.place_blueprint(post_def, Transform3D(Basis(), base + Vector3(-6, 0, 5)), {&"wood": 2, &"stone": 1})
	post.add_build_progress(post_def.build_seconds * 0.25)
	var paid: Dictionary = {&"wood": 1}
	var unstarted: Building = BuildManager.place_blueprint(fence_def, Transform3D(Basis(), base + Vector3(5, 0, -6)), paid)
	PerkManager.restore(player, [&"ember_heart"])
	ResourceManager.add(&"torch", 1)
	var torch: Node3D = _plant_torch(player)
	var lantern: MoonLantern = MoonLantern.find(get_tree())
	ResourceManager.add(&"glow_shards", 2)
	lantern.deliver(player)
	player.apply_signature()
	companion.set_task(Companion.Task.GUARD_BASE)
	await get_tree().process_frame
	if torch == null:
		_check(false, "planted an Ember Heart torch")
		return
	var torch_spot: Vector3 = torch.global_position
	var torch_dawns: int = int(torch.get("dawns_to_burn"))
	var torch_radius: float = float(torch.get("radius"))
	var fire_hp: int = fire.current_hp
	var fence_hp: int = fence.current_hp
	var post_hp: int = post.current_hp
	var post_progress: float = post.build_progress
	var shards: int = lantern.shards
	var player_damage: int = player.attack_damage
	var companion_damage: int = companion.attack_damage
	var data: Dictionary = SaveManager.parse(SaveManager.serialize(RunSession.snapshot()))
	_check(not data.is_empty() and (data["player"] as Dictionary).has("xp") and int((data["player"] as Dictionary).get("tier", -1)) == 1
		and (data["sibling"] as Dictionary).has("task"), "the save keeps each hero's entry whole (xp, tool tier, task)")
	var legacy: Dictionary = data.duplicate(true)
	for entry in legacy["buildings"]:
		(entry as Dictionary).erase("paid")
	(legacy["player"] as Dictionary).erase("tier")
	(legacy["player"] as Dictionary)["stick"] = true
	await _continue_from(data)
	player = get_tree().get_first_node_in_group("player") as Hero
	companion = get_tree().get_first_node_in_group("companions") as Companion
	for hero in [player, companion]:
		(hero as Node).set_physics_process(false)
	fire = _campfire()
	var bar: HealthBar3D = fire.health_bar()
	_check(fire.has_hearth and fire.current_hp == fire_hp and bar != null and bar.maximum() == fire.max_hp
		and is_equal_approx(bar.fill(), float(fire_hp) / float(fire.max_hp)),
		"the campfire comes back with its hearth at %d HP, and its bar shows it at once" % fire.current_hp)
	var loaded_fence: Building = _building_near(base + Vector3(7, 0, 3))
	var loaded_post: Building = _building_near(base + Vector3(-6, 0, 5))
	var loaded_unstarted: Building = _building_near(base + Vector3(5, 0, -6))
	_check(loaded_fence != null and loaded_fence.is_built() and loaded_fence.current_hp == fence_hp
		and absf(loaded_fence.global_rotation.y - 0.3) < 0.01 and loaded_fence.health_bar() != null
		and is_equal_approx(loaded_fence.health_bar().fill(), float(fence_hp) / float(loaded_fence.get_max_hp())),
		"the built fence comes back at %d HP, its bar showing it at once" % fence_hp)
	_check(loaded_post != null and loaded_post.is_blueprint() and is_equal_approx(loaded_post.build_progress, post_progress)
		and loaded_post.current_hp == post_hp and loaded_post.paid_cost() == {&"wood": 2, &"stone": 1},
		"the half-built watch post comes back at %d%% with what was paid for it" % roundi(post_progress * 100.0))
	var wood_before: int = ResourceManager.get_count(&"wood")
	_check(loaded_unstarted != null and BuildManager.remove_blueprint(loaded_unstarted)
		and ResourceManager.get_count(&"wood") - wood_before == 1, "an unstarted blueprint taken back refunds what was paid (1 Wood)")
	var loaded_torch: Node3D = null
	for node in get_tree().get_nodes_in_group("torches"):
		if (node as Node3D).global_position.distance_to(torch_spot) < 0.01:
			loaded_torch = node as Node3D
	_check(loaded_torch != null and int(loaded_torch.get("dawns_to_burn")) == torch_dawns
		and is_equal_approx(float(loaded_torch.get("radius")), torch_radius),
		"the Ember Heart torch comes back with its %d dawns left" % torch_dawns)
	_check(MoonLantern.find(get_tree()).shards == shards, "the Moon Lantern keeps its %d shards" % shards)
	_check(player.has_signature and player.attack_damage == player_damage and not companion.has_signature
		and companion.attack_damage == companion_damage and companion.current_task == Companion.Task.GUARD_BASE,
		"the heroes come back with their signature tools, damage and task")

	# A save from before perk cards: no paid cost, the old signature name.
	await _continue_from(legacy)
	player = get_tree().get_first_node_in_group("player") as Hero
	loaded_unstarted = _building_near(base + Vector3(5, 0, -6))
	wood_before = ResourceManager.get_count(&"wood")
	var price: int = int(BuildManager.cost_of(fence_def).get(&"wood", 0))
	_check(player.tool_tier == 1 and loaded_unstarted != null and BuildManager.remove_blueprint(loaded_unstarted)
		and ResourceManager.get_count(&"wood") - wood_before == price,
		"an older save: the stick counts as the signature tool, and the refund is today's price (%d Wood)" % price)
	await _start_fresh_run()
	_check(get_tree().get_nodes_in_group(Building.BUILDINGS_GROUP).filter(
		func(node: Node) -> bool: return not node.is_queued_for_deletion()).is_empty(),
		"a new run starts with no buildings")


## An in-place reset gives a
## live camp's heroes their base stats back, registered with
## progression again, and gets a downed hero up quietly; a restored
## level-up plays no bark.
func _run_reset_scenario() -> void:
	print("smoke: --- run reset scenario ---")
	GameManager.set_party(&"leo")
	await _start_fresh_run(_config(5.0))  # keep the player's picker open
	var player: Hero = Party.player_hero()
	var companion: Hero = Party.companion()
	for hero in [player, companion]:
		(hero as Node).set_physics_process(false)
	ProgressionManager.award_xp(player, ProgressionManager.get_xp_to_next_level(player), &"test")
	PerkManager.close_picker()
	player.apply_signature()
	var downs: Array = []
	companion.down_changed.connect(func(is_down: bool) -> void: downs.append(is_down))
	companion.clear_invulnerability()
	companion.take_damage(companion.max_hp * 10)
	_check(companion.is_down() and player.max_hp > player.stats.base_max_health, "the camp is levelled up, armed and has a downed companion")
	RunSession.reset(_config())
	_check(player.max_hp == player.stats.base_max_health and player.current_hp == player.max_hp
		and player.attack_damage == player.stats.base_attack_damage and not player.has_signature
		and is_equal_approx(player.get_attack_range(), player.hero.attack_range),
		"an in-place reset gives the hero its base stats back (%d HP, %d damage)" % [player.max_hp, player.attack_damage])
	ProgressionManager.award_xp(player, 3, &"test")
	_check(ProgressionManager.get_level(player) == 1 and ProgressionManager.get_xp(player) == 3,
		"after a reset the hero is registered with progression again (XP %d)" % ProgressionManager.get_xp(player))
	_check(not companion.is_down() and companion.current_hp == companion.max_hp and downs == [true],
		"a reset gets the downed companion up quietly (down_changed: %s)" % [downs])

	# Continue on a level-3 save: the replayed level-ups play no bark.
	await _start_fresh_run()
	var stats: CharacterStatsDefinition = ProgressionManager.get_stats(Party.player_hero())
	await _continue_with_xp(Party.PLAYER, stats.xp_threshold_for_level(3))
	var spoke: bool = false
	for hero in Party.heroes():
		var bubble: SpeechBubble = SpeechBubble.on(hero)
		if bubble != null and _bark_line(bubble.text, &"level_up", BarkDirector.speaker_id(hero)):
			spoke = true
	_check(ProgressionManager.get_level(Party.player_hero()) == 3 and not spoke,
		"Continue on a level-3 save plays no level-up bark")


## The building standing within 0.05 m of `spot`, or null.
func _building_near(spot: Vector3) -> Building:
	for node in get_tree().get_nodes_in_group(Building.BUILDINGS_GROUP):
		var building: Building = node as Building
		if building != null and not building.is_queued_for_deletion() and building.global_position.distance_to(spot) < 0.05:
			return building
	return null
