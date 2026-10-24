extends "res://tests/automated/smoke_scenario.gd"

## Perk cards: the picker, save and Continue, the shared and per-hero
## cards, the companion's own picks and the banner under the picker.


func run() -> void:
	await _run_perk_picker_scenario()
	await _run_perk_save_scenario()
	await _run_shared_perks_scenario()
	await _run_companion_perks_scenario()
	await _run_hero_perks_scenario()
	await _run_sibling_perks_scenario()
	await _run_perk_banner_scenario()
	await _run_perk_edge_cases_scenario()


## A level-up opens the picker, a pick applies its
## effect (Quick Hands: a shorter gather), the auto-pick fires after the
## timeout, and the game returns to normal speed each time.
func _run_perk_picker_scenario() -> void:
	print("smoke: --- perk picker scenario ---")
	await _start_fresh_run(_config(5.0))
	var player: Node = get_tree().get_first_node_in_group("player")
	var tree_node: ResourceNode = _find_resource_node(&"wood")
	var base_seconds: float = tree_node.gather_seconds_for(player)
	_check(is_equal_approx(base_seconds, tree_node.gather_time_seconds) and PerkManager.perks_of(player).is_empty(),
		"no perks at run start (gather %.1f s)" % base_seconds)

	# More cards than fit in a deal: seed one that has Quick Hands in it.
	for deal_seed in range(256):
		PerkManager.rng.seed = deal_seed
		if PerkManager.offer(player).any(func(p: PerkDefinition) -> bool: return p.id == &"quick_hands"):
			PerkManager.rng.seed = deal_seed
			break
	ProgressionManager.award_xp(player, ProgressionManager.get_xp_to_next_level(player), &"test")
	var picker: PerkPicker = PerkManager.picker()
	_check(ProgressionManager.get_level(player) == 2 and picker != null, "reaching level 2 opens the perk picker")
	if picker == null:
		return
	var ids: Array = picker.cards().map(func(p: PerkDefinition) -> StringName: return p.id)
	var distinct: Dictionary = {}
	for id in ids:
		distinct[id] = true
	_check(ids.size() == mini(3, PerkManager.definitions().size()) and distinct.size() == ids.size()
		and picker.card_buttons().size() == ids.size(), "the picker deals distinct cards (%s)" % ", ".join(ids))
	_check(is_equal_approx(Engine.time_scale, SPEED * PerkPicker.SLOW_FACTOR), "the game runs at 10% speed while picking")
	var index: int = ids.find(&"quick_hands")
	_check(index >= 0, "Quick Hands is on offer")
	# Press its number key, as a player would.
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_1 + index
	key.keycode = KEY_1 + index
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(PerkManager.has(player, &"quick_hands") and not PerkManager.is_picking(), "pressing %d takes Quick Hands" % (index + 1))
	_check(is_equal_approx(Engine.time_scale, SPEED), "normal speed once a card is picked")
	_check(is_equal_approx(tree_node.gather_seconds_for(player), base_seconds * 0.7), "Quick Hands: gathering takes 30% less time")
	# The gather itself runs the shorter time (on a node nobody is using).
	var started: bool = false
	for node in get_tree().current_scene.find_children("*", "ResourceNode", true, false):
		var gather_node: ResourceNode = node as ResourceNode
		if gather_node.begin_gather(player):
			var timer: Timer = gather_node.get("_gather_timer")
			started = is_equal_approx(timer.wait_time, gather_node.gather_time_seconds * 0.7)
			gather_node.cancel_gather(player)
			break
	_check(started, "the gather timer runs the shorter time")

	# The pool is used up (Quick Hands does not stack): no picker.
	if PerkManager.offer(player).is_empty():
		ProgressionManager.award_xp(player, ProgressionManager.get_xp_to_next_level(player), &"test")
		_check(ProgressionManager.get_level(player) == 3 and not PerkManager.is_picking(), "an empty pool skips the picker")

	# A new run: level-ups replayed from a save never open the picker.
	await _start_fresh_run(_config(0.5))
	player = get_tree().get_first_node_in_group("player")
	_check(PerkManager.perks_of(player).is_empty(), "a new run starts with no perks")
	var stats: CharacterStatsDefinition = ProgressionManager.get_stats(player)
	await _continue_with_xp(Party.PLAYER, stats.xp_threshold_for_level(2), _config(0.5))
	player = Party.player_hero()
	_check(ProgressionManager.get_level(player) == 2 and not PerkManager.is_picking(), "levelling up while restoring a save opens no picker")

	# Nobody picks: the first card is taken after the timeout, through a hit-stop.
	ProgressionManager.award_xp(player, ProgressionManager.get_xp_to_next_level(player), &"test")
	picker = PerkManager.picker()
	_check(picker != null, "the next level-up opens the picker")
	if picker == null:
		return
	var first: StringName = picker.cards()[0].id
	Fx.hit_stop(0.05)
	await get_tree().create_timer(0.2, true, false, true).timeout
	_check(PerkManager.is_picking(), "the picker waits before it auto-picks")
	await get_tree().create_timer(0.6, true, false, true).timeout
	_check(PerkManager.has(player, first) and not PerkManager.is_picking(), "the auto-pick takes the first card (%s)" % first)
	_check(is_equal_approx(Engine.time_scale, SPEED), "normal speed after the auto-pick (%.2f)" % Engine.time_scale)


## The perks both heroes hold survive save and Continue, quietly
## (no picker), and a save from before perks loads with none.
func _run_perk_save_scenario() -> void:
	print("smoke: --- perk save scenario ---")
	await _start_fresh_run()
	var player: Node = get_tree().get_first_node_in_group("player")
	var sibling: Node = get_tree().get_first_node_in_group("companions")
	ProgressionManager.award_xp(player, ProgressionManager.get_xp_to_next_level(player), &"test")
	PerkManager.restore(player, [])  # forget the auto-picked card; take a known one
	PerkManager.take(player, &"quick_hands")
	PerkManager.take(sibling, &"quick_hands")
	var data: Dictionary = RunSession.snapshot()
	_check(data["player"].get("perks", []) == ["quick_hands"] and data["sibling"].get("perks", []) == ["quick_hands"],
		"the save lists each hero's perks")
	await _continue_from(SaveManager.parse(SaveManager.serialize(data)))
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	sibling = get_tree().get_first_node_in_group("companions")
	var tree_node: ResourceNode = _find_resource_node(&"wood")
	_check(PerkManager.perks_of(player) == [&"quick_hands"] and PerkManager.perks_of(sibling) == [&"quick_hands"]
		and not PerkManager.is_picking(), "Continue restores both heroes' perks without the picker")
	_check(is_equal_approx(tree_node.gather_seconds_for(player), tree_node.gather_time_seconds * 0.7),
		"a restored Quick Hands still speeds up gathering")

	# A save from before perks: no "perks" keys at all.
	data = RunSession.snapshot()
	(data["player"] as Dictionary).erase("perks")
	(data["sibling"] as Dictionary).erase("perks")
	await _continue_from(SaveManager.parse(SaveManager.serialize(data)))
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	sibling = get_tree().get_first_node_in_group("companions")
	_check(GameManager.is_playing() and PerkManager.perks_of(player).is_empty() and PerkManager.perks_of(sibling).is_empty()
		and not PerkManager.is_picking(), "a save from before perks loads with no perks")


## Ember Heart (torch life and radius), Berry Belly (snack
## healing) and Builder's Knack (Wood cost, in the build menu too).
func _run_shared_perks_scenario() -> void:
	print("smoke: --- shared perks scenario ---")
	await _start_fresh_run()
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	for id in [&"ember_heart", &"berry_belly", &"builders_knack"]:
		var perk: PerkDefinition = PerkManager.get_definition(id)
		_check(perk != null and perk.pool == &"shared" and not PerkManager.has(player, id), "%s is a shared card, not yet held" % id)

	# Ember Heart: a torch planted after it burns one more dawn, wider.
	ResourceManager.add(&"torch", 2)
	var plain: Node3D = _plant_torch(player)
	_check(PerkManager.take(player, &"ember_heart"), "took Ember Heart")
	var ember: Node3D = _plant_torch(player)
	if plain == null or ember == null:
		_check(false, "planted two torches")
		return
	var factor: float = PerkManager.get_definition(&"ember_heart").value
	var base_radius: float = float(plain.get("radius"))
	var plain_fire: Node = plain.get_node("Fire")
	var ember_fire: Node = ember.get_node("Fire")
	var ember_light: OmniLight3D = ember_fire.get("_light") as OmniLight3D
	_check(is_equal_approx(float(ember.get("radius")), base_radius * factor),
		"Ember Heart: torch radius %.1f -> %.1f m" % [base_radius, float(ember.get("radius"))])
	_check(is_equal_approx((ember.get_node("Radius") as Node3D).scale.x, factor * (plain.get_node("Radius") as Node3D).scale.x),
		"Ember Heart: the torch's ring grows with the radius")
	_check(is_equal_approx(float(ember_fire.get("light_range")), float(plain_fire.get("light_range")) * factor)
		and ember_light != null and is_equal_approx(ember_light.omni_range, float(ember_fire.get("light_range"))),
		"Ember Heart: the torch's light reaches %.1f m" % float(ember_fire.get("light_range")))
	var past_edge: Vector3 = Vector3(base_radius + 0.5, 0, 0)
	_check(ember.call("affects", ember.global_position + past_edge) and not plain.call("affects", plain.global_position + past_edge),
		"Ember Heart: the torch reaches imps past the old radius")
	plain.call("_on_dawn_started", TimeManager.day_number + 1)
	ember.call("_on_dawn_started", TimeManager.day_number + 1)
	_check(not plain.call("affects", plain.global_position) and ember.call("affects", ember.global_position),
		"Ember Heart: the torch outlasts the first dawn")
	ember.call("_on_dawn_started", TimeManager.day_number + 2)
	_check(not ember.call("affects", ember.global_position), "Ember Heart: the torch goes out at the second dawn")

	# Berry Belly: a Berry Snack heals 50% more.
	player.set("max_hp", 500)
	player.set("current_hp", 100)
	ResourceManager.add(&"snack", 2)
	player.call("try_eat_berries")
	var plain_heal: int = int(player.get("current_hp")) - 100
	_check(PerkManager.take(player, &"berry_belly"), "took Berry Belly")
	player.set("current_hp", 100)
	player.call("try_eat_berries")
	var belly_heal: int = int(player.get("current_hp")) - 100
	_check(plain_heal == int(player.get("heal_per_snack")) and belly_heal == roundi(plain_heal * 1.5),
		"Berry Belly: a snack heals %d HP, not %d" % [belly_heal, plain_heal])

	# Builder's Knack: 1 Wood less, never below 0, everywhere the cost shows.
	var fence: BuildingDefinition = BuildManager.get_definition(&"wooden_fence")
	var full_wood: int = int(fence.cost[&"wood"])
	_check(int(BuildManager.cost_of(fence).get(&"wood", 0)) == full_wood, "a fence costs %d Wood without the perk" % full_wood)
	_check(PerkManager.take(player, &"builders_knack"), "took Builder's Knack")
	_check(int(BuildManager.cost_of(fence).get(&"wood", 0)) == full_wood - 1, "Builder's Knack: a fence costs %d Wood" % (full_wood - 1))
	var cheap: BuildingDefinition = BuildingDefinition.new()
	cheap.cost = {&"wood": 1, &"stone": 2}
	var cheap_cost: Dictionary = BuildManager.cost_of(cheap)
	_check(not cheap_cost.has(&"wood") and int(cheap_cost.get(&"stone", 0)) == 2 and int(cheap.cost[&"wood"]) == 1,
		"Builder's Knack: a 1-Wood cost drops to nothing, never below 0")
	ResourceManager.add(&"wood", full_wood - 1 - ResourceManager.get_count(&"wood"))
	_check(ResourceManager.can_afford(BuildManager.cost_of(fence)) and not ResourceManager.can_afford(fence.cost),
		"Builder's Knack: %d Wood is enough for a fence" % (full_wood - 1))
	_check(BuildManager.enter_build_mode(fence), "build mode with the fence")
	await get_tree().process_frame
	var hud: Node = get_tree().get_first_node_in_group("hud")
	var shown: Array[String] = []
	for row in (hud.get("_build_row") as Node).get_children():
		if row is HBoxContainer and not row.is_queued_for_deletion():
			for label in row.find_children("*", "Label", true, false):
				shown.append((label as Label).text)
	_check(shown == ["%d" % (full_wood - 1)], "Builder's Knack: the build menu shows %s Wood" % ", ".join(shown))
	BuildManager.set("_is_valid", true)
	var blueprints_before: int = get_tree().get_nodes_in_group(Building.BLUEPRINT_GROUP).size()
	BuildManager.call("_try_confirm")
	var placed: Array[Node] = get_tree().get_nodes_in_group(Building.BLUEPRINT_GROUP)
	_check(placed.size() == blueprints_before + 1 and ResourceManager.get_count(&"wood") == 0,
		"Builder's Knack: placing a fence spends %d Wood" % (full_wood - 1))
	BuildManager.exit_build_mode()
	if placed.size() > blueprints_before:
		_check(BuildManager.remove_blueprint(placed[placed.size() - 1] as Building) and ResourceManager.get_count(&"wood") == full_wood - 1,
			"Builder's Knack: taking it back refunds the %d Wood paid" % (full_wood - 1))


## The companion takes a random card by itself, with a
## toast, never the picker; its own pool's rules hold.
func _run_companion_perks_scenario() -> void:
	print("smoke: --- companion perks scenario ---")
	await _start_fresh_run(_config(5.0, 6))  # the player's level-up would open a picker
	var hud: Node = get_tree().get_first_node_in_group("hud")
	var companion: Node = get_tree().get_first_node_in_group("companions")
	var hero: HeroDefinition = companion.get("hero") as HeroDefinition
	ProgressionManager.award_xp(companion, ProgressionManager.get_xp_to_next_level(companion), &"test")
	var taken: Array[StringName] = PerkManager.perks_of(companion)
	_check(ProgressionManager.get_level(companion) == 2 and taken.size() == 1 and not PerkManager.is_picking(),
		"a companion level-up takes a card by itself, no picker (%s)" % ", ".join(taken))
	if taken.is_empty():
		return
	var perk: PerkDefinition = PerkManager.get_definition(taken[0])
	var toasts: Array = hud.call("toasts")
	var line: String = "%s took %s!" % [hero.display_name, perk.display_name]
	_check(toasts.size() == 1 and (toasts[0] as HudToast).text() == line, "a toast says \"%s\"" % line)
	await get_tree().process_frame
	await get_tree().process_frame
	if not toasts.is_empty():
		var toast_rect: Rect2 = (toasts[0] as HudToast).get_global_rect()
		var banner_rect: Rect2 = (hud.get("_banner_plate") as Control).get_global_rect()
		var story_rect: Rect2 = (hud.get("_story_host") as Control).get_global_rect().grow_individual(0, 0, 430, 300)
		_check(not toast_rect.intersects(banner_rect) and not toast_rect.intersects(story_rect)
			and toast_rect.end.x <= 1280.0 and toast_rect.position.y > 60.0,
			"the toast sits on the right under the tray, clear of the banner and story card (%s)" % toast_rect)

	# Same pool rules as the picker: its own hero's cards, no repeats
	# unless the card stacks, nothing once the pool is used up.
	for i in PerkManager.definitions().size() + 1:
		ProgressionManager.award_xp(companion, ProgressionManager.get_xp_to_next_level(companion), &"test")
	taken = PerkManager.perks_of(companion)
	var fair: bool = not PerkManager.is_picking()
	for id in taken:
		var card: PerkDefinition = PerkManager.get_definition(id)
		fair = fair and card.is_for(hero.id, true) and (card.stacks or taken.count(id) == 1)
	var own: int = 0
	var any_stacks: bool = false
	for card in PerkManager.definitions():
		if card.is_for(hero.id, true):
			own += 1
			any_stacks = any_stacks or card.stacks
	_check(fair and (any_stacks or (taken.size() == own and PerkManager.offer(companion).is_empty())),
		"the companion's cards follow the pool rules: own hero's, never player-only, no repeats, stops when used up (%s)" % ", ".join(taken))
	var player: Node = get_tree().get_first_node_in_group("player")
	_check(PerkManager.perks_of(player).is_empty(), "the companion's cards are not the player's")

	# The toast fades by itself, in real time.
	await get_tree().create_timer(HudToast.POP_SECONDS + HudToast.SECONDS + HudToast.FADE_SECONDS + 0.3, true, false, true).timeout
	_check((hud.call("toasts") as Array).is_empty() and (hud.get("_toast_stack") as Node).get_child_count() == 0, "the toast fades and frees itself")

	# Level-ups replayed from a save take no card and show no toast.
	await _start_fresh_run()
	companion = get_tree().get_first_node_in_group("companions")
	var stats: CharacterStatsDefinition = ProgressionManager.get_stats(companion)
	await _continue_with_xp(Party.COMPANION, stats.xp_threshold_for_level(3))
	hud = get_tree().get_first_node_in_group("hud")
	companion = get_tree().get_first_node_in_group("companions")
	_check(ProgressionManager.get_level(companion) == 3 and PerkManager.perks_of(companion).is_empty()
		and (hud.call("toasts") as Array).is_empty(), "a companion level-up while restoring a save takes no card")


## Each hero is dealt their own cards and never the other
## hero's, and Big Swing, Stand Firm, Ricochet and Eagle Eye work whether
## the hero is played or tags along as the companion.
func _run_hero_perks_scenario() -> void:
	print("smoke: --- hero perks scenario ---")
	for hero_id in [&"leo", &"nela"]:
		await _start_fresh_run(_party(hero_id))
		var player: Node3D = get_tree().get_first_node_in_group("player")
		var companion: Node3D = get_tree().get_first_node_in_group("companions")
		# Hold the companion still (the test swings for it), and stop the
		# watch post shooting the staged mobs.
		companion.set_physics_process(false)
		for building in get_tree().current_scene.find_children("*", "Building", true, false):
			building.set_physics_process(false)
		for who in [player, companion]:
			var own: StringName = (who.get("hero") as HeroDefinition).id
			var other: StringName = &"nela" if own == &"leo" else &"leo"
			var dealt_own: bool = true
			var dealt_other: bool = false
			for i in 20:
				var pools: Array = PerkManager.offer(who, 99).map(func(p: PerkDefinition) -> StringName: return p.pool)
				dealt_own = dealt_own and pools.count(own) >= 2
				dealt_other = dealt_other or pools.has(other)
			_check(dealt_own and not dealt_other, "%s is dealt their own cards and never %s's" % [own, other])
		for who in [player, companion]:
			if (who.get("hero") as HeroDefinition).id == &"leo":
				await _check_leo_perks(who)
			else:
				await _check_nela_perks(who)


## The sibling cards work whichever hero is the player.
## Twin Strike hits harder only on a mob the other hero hit within
## HeroHits.TWIN_STRIKE_SECONDS; Cheer Up's level-ups heal the other hero.
func _run_sibling_perks_scenario() -> void:
	print("smoke: --- sibling perks scenario ---")
	for hero_id in [&"leo", &"nela"]:
		await _start_fresh_run(_party(hero_id))
		var player: Node3D = get_tree().get_first_node_in_group("player")
		var companion: Node3D = get_tree().get_first_node_in_group("companions")
		companion.set_physics_process(false)
		for building in get_tree().current_scene.find_children("*", "Building", true, false):
			building.set_physics_process(false)
		_check(Party.other(player) == companion and Party.other(companion) == player,
			"party %s: each hero's other hero is their sibling" % hero_id)
		for who in [player, companion]:
			await _check_twin_strike(who, Party.other(who))
		for who in [player, companion]:
			_check_cheer_up(who, Party.other(who))


## The centre banner ("NIGHT N!") hides while the perk
## picker is open, so it never sits on the picker's heading, and comes
## back once a card is taken.
func _run_perk_banner_scenario() -> void:
	print("smoke: --- perk banner scenario ---")
	await _start_fresh_run(_config(5.0))
	var player: Node = get_tree().get_first_node_in_group("player")
	var hud: Node = get_tree().get_first_node_in_group("hud")
	var plate: Control = hud.get("_banner_plate") as Control
	hud.show_banner("Night 9!")
	# Polled: a fixed wait can end in a long frame before the fade-in steps.
	var shown: Callable = func() -> bool: return plate.modulate.a > 0.9
	_check(await _wait_until(shown, 1.0), "the night banner shows (alpha %.2f)" % plate.modulate.a)
	ProgressionManager.award_xp(player, ProgressionManager.get_xp_to_next_level(player), &"test")
	var picker: PerkPicker = PerkManager.picker()
	_check(picker != null and is_zero_approx(plate.modulate.a) and hud.is_banner_hidden(),
		"the banner hides while the perk picker is open")
	if picker == null:
		return
	picker.pick(0)
	# The level-up restarted the banner (its own fade-in) under the picker.
	_check(await _wait_until(shown, 1.0) and not hud.is_banner_hidden(),
		"the banner comes back once a card is taken (alpha %.2f)" % plate.modulate.a)


## The companion never draws a player-only
## card; a card the dawn autosave missed (a picker still open, a level-up
## waiting behind it) is dealt again on Continue; Ember Heart torches and
## a blueprint's paid cost survive Continue; the Wood discount follows
## the perks; and stacking Twin Strike copies multiply.
func _run_perk_edge_cases_scenario() -> void:
	print("smoke: --- perk edge cases scenario ---")
	await _start_fresh_run(_config(5.0))
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var companion: Node3D = get_tree().get_first_node_in_group("companions")
	companion.set_physics_process(false)
	var player_only: Array = PerkManager.definitions().filter(func(p: PerkDefinition) -> bool: return p.player_only).map(
		func(p: PerkDefinition) -> StringName: return p.id)
	_check(player_only == [&"berry_belly", &"ember_heart"], "Berry Belly and Ember Heart are player-only cards (%s)" % [player_only])
	var companion_deal: Array[PerkDefinition] = PerkManager.offer(companion, 99)
	_check(not companion_deal.is_empty() and not companion_deal.any(func(p: PerkDefinition) -> bool: return p.player_only)
		and PerkManager.offer(player, 99).any(func(p: PerkDefinition) -> bool: return p.player_only),
		"the companion is never dealt a player-only card; the player is")

	# The dawn autosave lands while the picker is open, with one more
	# level-up queued behind it, and the companion is a card short too.
	ProgressionManager.award_xp(player, ProgressionManager.get_xp_to_next_level(player), &"test")
	ProgressionManager.award_xp(player, ProgressionManager.get_xp_to_next_level(player), &"test")
	ProgressionManager.award_xp(companion, ProgressionManager.get_xp_to_next_level(companion), &"test")
	ProgressionManager.award_xp(companion, ProgressionManager.get_xp_to_next_level(companion), &"test")
	PerkManager.restore(companion, PerkManager.perks_of(companion).slice(0, 1))
	_check(ProgressionManager.get_level(player) == 3 and PerkManager.is_picking() and PerkManager.perks_of(player).is_empty()
		and PerkManager.perks_of(companion).size() == 1, "saved mid-pick: the player holds 0 of 2 cards, the companion 1 of 2")
	var data: Dictionary = RunSession.snapshot()
	PerkManager.close_picker()
	await _continue_from(SaveManager.parse(SaveManager.serialize(data)))
	await get_tree().process_frame
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	companion = get_tree().get_first_node_in_group("companions")
	companion.set_physics_process(false)
	var cards: Array[StringName] = PerkManager.perks_of(companion)
	_check(PerkManager.perks_of(player).size() == 2 and cards.size() == 2 and not PerkManager.is_picking(),
		"Continue deals the cards the save missed (player %s, companion %s)" % [PerkManager.perks_of(player), cards])
	# With the picker on, the top-up opens it, and queues the rest.
	PerkManager.auto_pick_seconds = 5.0
	PerkManager.restore(player, [])
	PerkManager.top_up(player)
	_check(PerkManager.is_picking() and int((PerkManager.get("_pending") as Dictionary).get(player, 0)) == 1,
		"a top-up of 2 cards opens the picker and queues the second")
	PerkManager.close_picker()
	PerkManager.auto_pick_seconds = 0.0
	PerkManager.restore(player, [])
	PerkManager.restore(companion, [])  # its Builder's Knack would count for the party

	# Builder's Knack: the cached discount follows taking and dropping it.
	var fence: BuildingDefinition = BuildManager.get_definition(&"wooden_fence")
	var full_wood: int = int(fence.cost[&"wood"])
	_check(int(BuildManager.cost_of(fence).get(&"wood", 0)) == full_wood, "no Builder's Knack: a fence costs %d Wood" % full_wood)
	PerkManager.take(player, &"builders_knack")
	_check(int(BuildManager.cost_of(fence).get(&"wood", 0)) == full_wood - 1, "Builder's Knack taken: the cost drops at once")
	PerkManager.restore(player, [])
	_check(int(BuildManager.cost_of(fence).get(&"wood", 0)) == full_wood, "Builder's Knack dropped: the cost is back at once")
	PerkManager.restore(player, [&"builders_knack", &"ember_heart"])

	# A blueprint paid for with the discount, and a burning Ember Heart
	# torch that has seen one dawn, both through save and Continue.
	ResourceManager.add(&"wood", full_wood)
	_check(BuildManager.enter_build_mode(fence), "build mode with the fence")
	await get_tree().process_frame
	BuildManager.set("_is_valid", true)
	var before: Array[Node] = get_tree().get_nodes_in_group(Building.BLUEPRINT_GROUP)
	BuildManager.call("_try_confirm")
	BuildManager.exit_build_mode()
	var blueprint: Building = null
	for node in get_tree().get_nodes_in_group(Building.BLUEPRINT_GROUP):
		if not before.has(node):
			blueprint = node as Building
	_check(blueprint != null and int(blueprint.paid_cost().get(&"wood", 0)) == full_wood - 1,
		"the blueprint records the %d Wood paid" % (full_wood - 1))
	ResourceManager.add(&"torch", 1)
	var torch: Node3D = _plant_torch(player)
	if blueprint == null or torch == null:
		_check(false, "placed a blueprint and planted a torch")
		return
	torch.call("_on_dawn_started", TimeManager.day_number + 1)
	var radius: float = float(torch.get("radius"))
	var ring: float = (torch.get_node("Radius") as Node3D).scale.x
	var spot: Vector3 = torch.global_position
	var site: Vector3 = blueprint.global_position
	data = RunSession.snapshot()
	var saved_torches: Array = data.get("torches", [])
	_check(saved_torches.size() == 1, "the save keeps the Ember Heart torch still burning (%d)" % saved_torches.size())
	torch.queue_free()
	blueprint.queue_free()
	await _continue_from(SaveManager.parse(SaveManager.serialize(data)))
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	var loaded_torch: Node3D = null
	for node in get_tree().get_nodes_in_group("torches"):
		if (node as Node3D).global_position.distance_to(spot) < 0.01:
			loaded_torch = node as Node3D
	_check(loaded_torch != null and is_equal_approx(float(loaded_torch.get("radius")), radius)
		and is_equal_approx((loaded_torch.get_node("Radius") as Node3D).scale.x, ring) and int(loaded_torch.get("dawns_to_burn")) == 1,
		"Continue keeps the Ember Heart torch: same spot, %.1f m, one dawn left" % radius)
	if loaded_torch != null:
		loaded_torch.call("_on_dawn_started", TimeManager.day_number + 1)
		_check(not loaded_torch.call("affects", loaded_torch.global_position), "the kept torch goes out at the next dawn")
	var loaded_print: Building = null
	for node in get_tree().get_nodes_in_group(Building.BLUEPRINT_GROUP):
		if (node as Building).definition == fence and (node as Building).global_position.distance_to(site) < 0.01:
			loaded_print = node as Building
	PerkManager.restore(player, [])  # the refund is what was paid, not today's price
	var wood_before: int = ResourceManager.get_count(&"wood")
	_check(loaded_print != null and BuildManager.remove_blueprint(loaded_print)
		and ResourceManager.get_count(&"wood") - wood_before == full_wood - 1,
		"after Continue, taking the blueprint back refunds the %d Wood paid" % (full_wood - 1))

	# Twin Strike, if it stacked: each copy multiplies.
	for building in get_tree().current_scene.find_children("*", "Building", true, false):
		building.set_physics_process(false)
	companion = get_tree().get_first_node_in_group("companions")
	var twin: PerkDefinition = PerkManager.get_definition(&"twin_strike")
	var stacked: bool = twin.stacks
	twin.stacks = true
	PerkManager.restore(player, [&"twin_strike", &"twin_strike"])
	var beast_def: MobDefinition = load("res://resources/mobs/bramble_beast.tres") as MobDefinition
	var mob: Mob = _spawn_mob(beast_def, _campfire().global_position + Vector3(9, 0, 0))
	mob.set_physics_process(false)
	await get_tree().process_frame
	HeroHits.strike(companion, mob, 1)
	var factor: float = HeroHits.damage_factor(player, mob)
	_check(is_equal_approx(factor, twin.value * twin.value), "two Twin Strike copies multiply (x%.2f)" % factor)
	twin.stacks = stacked
	PerkManager.restore(player, [])
	await _clear_staged_mobs()


func _check_leo_perks(leo: Node3D) -> void:
	var role: String = "player" if leo.is_in_group("player") else "companion"
	var fire: Node3D = _campfire()
	var spot: Vector3 = fire.global_position + Vector3(9, 0, 0)
	leo.global_position = spot
	var beast_def: MobDefinition = load("res://resources/mobs/bramble_beast.tres") as MobDefinition
	var first: Mob = _spawn_mob(beast_def, spot + Vector3(1.5, 0, 0))
	var second: Mob = _spawn_mob(beast_def, spot + Vector3(1.5, 0, 1.5))
	first.set_physics_process(false)
	second.set_physics_process(false)
	await get_tree().process_frame
	# Big Swing: one swing, two mobs.
	await _attack_and_wait(leo, first)
	_check(first.current_hp < beast_def.max_hp and second.current_hp == beast_def.max_hp, "%s Leo: a swing hits one mob" % role)
	var hp: Array[int] = [first.current_hp, second.current_hp]
	PerkManager.take(leo, &"big_swing")
	var both_hit: bool = await _attack_and_wait_until(leo, first,
		func() -> bool: return first.current_hp < hp[0] and second.current_hp < hp[1])
	_check(both_hit, "%s Leo, Big Swing: a swing hits two mobs" % role)
	await _clear_staged_mobs()

	# Stand Firm: 25% less damage near the fire, none away from it.
	PerkManager.take(leo, &"stand_firm")
	var taken: Array[int] = []
	for offset in [Vector3(2.5, 0, 0), Vector3(9, 0, 0)]:
		leo.global_position = fire.global_position + offset
		(leo as Hero).clear_invulnerability()
		var before: int = int(leo.get("current_hp"))
		leo.call("take_damage", 8, null)
		taken.append(before - int(leo.get("current_hp")))
	_check(taken == [6, 8], "%s Leo, Stand Firm: 8 damage is 6 near the fire, 8 away (%s)" % [role, taken])
	leo.set("current_hp", int(leo.get("max_hp")))
	(leo as Hero).clear_invulnerability()


func _check_nela_perks(nela: Node3D) -> void:
	var role: String = "player" if nela.is_in_group("player") else "companion"
	var spot: Vector3 = _campfire().global_position + Vector3(9, 0, 0)
	nela.global_position = spot
	var beast_def: MobDefinition = load("res://resources/mobs/bramble_beast.tres") as MobDefinition
	var first: Mob = _spawn_mob(beast_def, spot + Vector3(1.5, 0, 0))
	var second: Mob = _spawn_mob(beast_def, spot + Vector3(1.5, 0, 2.5))
	first.set_physics_process(false)
	second.set_physics_process(false)
	await get_tree().process_frame
	# Ricochet: the pebble bounces on to a second mob.
	await _attack_and_wait(nela, first)
	_check(first.current_hp < beast_def.max_hp and second.current_hp == beast_def.max_hp, "%s Nela: a pebble hits one mob" % role)
	var hp: Array[int] = [first.current_hp, second.current_hp]
	PerkManager.take(nela, &"ricochet")
	var bounced: bool = await _attack_and_wait_until(nela, first,
		func() -> bool: return first.current_hp < hp[0] and second.current_hp < hp[1])
	_check(bounced, "%s Nela, Ricochet: the pebble bounces to a second mob" % role)
	await _clear_staged_mobs()

	# Eagle Eye: 20% more reach, for the attack and for finding a target.
	var reach: float = float(nela.call("get_attack_range"))
	# The player looks a little past her reach (x1.2), the companion at it.
	var past: float = 1.3 if nela.is_in_group("player") else 1.1
	var far: Mob = _spawn_mob(beast_def, spot + Vector3(reach * past, 0, 0))
	far.set_physics_process(false)
	await get_tree().process_frame
	var found_before: bool = _would_target(nela, far, reach)
	PerkManager.take(nela, &"eagle_eye")
	var longer: float = float(nela.call("get_attack_range"))
	_check(is_equal_approx(longer, reach * 1.2), "%s Nela, Eagle Eye: reach %.2f -> %.2f m" % [role, reach, longer])
	_check(not found_before and _would_target(nela, far, longer), "%s Nela, Eagle Eye: targets a mob past her old reach" % role)
	if nela.is_in_group("player"):
		_check(is_equal_approx(float(nela.call("auto_attack_radius")), maxf(longer * 1.3, 3.5)), "player Nela, Eagle Eye: auto-attack reaches further")
	await _clear_staged_mobs()


## One attack from `hero` on `mob`, through the Hero interface, then
## waits for the swing or the pebble (and any bounce) to land. For a
## check that nothing more was hit: a fixed wait can only end early.
func _attack_and_wait(hero: Node3D, mob: Mob) -> void:
	(hero as Hero).attack(mob)
	await _wait(1.2)


## One attack from `hero` on `mob`, then waits until `landed` holds (at
## most 1.2 game s); returns whether it did. A fixed wait races the
## pebble's and the bounce's tweens (or the swing's wind-up): at the
## smoke's 4x speed 1.2 s is two stalled frames, and the second can fire
## the timer before the bounce's tween lands, in the same frame.
func _attack_and_wait_until(hero: Node3D, mob: Mob, landed: Callable) -> bool:
	(hero as Hero).attack(mob)
	return await _wait_until(landed, 1.2)


## True if `hero` would pick `mob` as a target at its current reach.
func _would_target(hero: Node3D, mob: Mob, reach: float) -> bool:
	# The player's hero targets a little past its reach (Space, 1.2x).
	var within: float = reach * 1.2 if Party.role_of(hero) == Party.PLAYER else reach
	return (hero as Hero).nearest_mob(within) == mob


func _check_twin_strike(hero: Node3D, other: Node3D) -> void:
	var role: String = "player" if hero.is_in_group("player") else "companion"
	var spot: Vector3 = _campfire().global_position + Vector3(9, 0, 0)
	var beast_def: MobDefinition = load("res://resources/mobs/bramble_beast.tres") as MobDefinition
	var mob: Mob = _spawn_mob(beast_def, spot)
	var lone: Mob = _spawn_mob(beast_def, spot + Vector3(0, 0, 3))
	mob.set_physics_process(false)
	lone.set_physics_process(false)
	await get_tree().process_frame
	PerkManager.take(hero, &"twin_strike")
	var hits: Array[int] = []
	hits.append(HeroHits.strike(hero, lone, 4))  # nobody else on it
	hits.append(HeroHits.strike(hero, lone, 4))  # only its own hits
	HeroHits.strike(other, mob, 1)
	hits.append(HeroHits.strike(hero, mob, 4))  # the other hero just hit it
	await _wait(HeroHits.TWIN_STRIKE_SECONDS + 0.5)
	hits.append(HeroHits.strike(hero, mob, 4))  # too long ago
	_check(hits == [4, 4, 6, 4], "%s, Twin Strike: +50%% only on a mob the other hero just hit (%s)" % [role, hits])
	PerkManager.restore(hero, [])
	await _clear_staged_mobs()


func _check_cheer_up(hero: Node3D, other: Node3D) -> void:
	var role: String = "player" if hero.is_in_group("player") else "companion"
	PerkManager.restore(hero, [])
	PerkManager.restore(other, [])
	other.set("current_hp", 10)
	ProgressionManager.award_xp(hero, ProgressionManager.get_xp_to_next_level(hero), &"test")
	var without: int = int(other.get("current_hp"))
	PerkManager.restore(hero, [&"cheer_up"])
	PerkManager.restore(other, [])
	ProgressionManager.award_xp(hero, ProgressionManager.get_xp_to_next_level(hero), &"test")
	var with_perk: int = int(other.get("current_hp"))
	var share: int = HeroHits.cheer_up_heal(other)
	_check(without == 10 and share > 0 and with_perk == 10 + share,
		"%s, Cheer Up: a level-up heals the other hero (%d -> %d, +%d)" % [role, without, with_perk, share])
	other.set("current_hp", int(other.get("max_hp")))
	PerkManager.restore(hero, [])
	PerkManager.restore(other, [])
