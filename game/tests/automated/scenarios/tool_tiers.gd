extends "res://tests/automated/smoke_scenario.gd"

## Leo's and Nela's tool tiers, as the player's hero and as the
## companion.


func run() -> void:
	await _run_tool_tiers_scenario()
	await _run_double_sling_scenario()


## Leo's tier path, as the player's hero and as the
## companion. The Ember Stick (tier 2) is offered only once the Sturdy
## Stick (tier 1) is owned, costs 2 Glow Shards, its hits burn 3 times,
## it lights Leo at night, the HUD's attack slot shows the tier, and the
## save keeps the tier (old `signature: true` saves load as tier 1).
func _run_tool_tiers_scenario() -> void:
	print("smoke: --- tool tiers scenario ---")
	for party_hero in [&"leo", &"nela"]:
		await _start_fresh_run(_party(party_hero))
		var leo: Hero = HeroRoster.node_for(get_tree(), &"leo") as Hero
		var role: String = "player" if party_hero == &"leo" else "companion"
		for hero in Party.heroes():
			(hero as Node).set_physics_process(false)
		for building in get_tree().current_scene.find_children("*", "Building", true, false):
			building.set_physics_process(false)
		var table: Building = _spawn_building(&"crafting_table", leo.global_position + Vector3(4, 0, -4))
		for item in [&"wood", &"scrap", &"clay"]:
			ResourceManager.add(item, 10)
		ResourceManager.add(&"glow_shards", 5)
		var sturdy: CraftingRecipe = _recipe(&"sturdy_stick")
		var ember: CraftingRecipe = _recipe(&"ember_stick")
		_check(ember != null and not CraftingManager.is_offered(ember) and not CraftingManager.can_craft(ember)
			and CraftingManager.is_offered(sturdy), "Leo as %s: the Ember Stick is not offered before the Sturdy Stick" % role)
		var damage: int = leo.get_attack_damage()
		_check(CraftingManager.craft(sturdy, null) and leo.tool_tier == 1 and leo.get_attack_damage() == damage + 2,
			"Leo as %s: the Sturdy Stick is tier 1 (+2 damage)" % role)
		_check(CraftingManager.is_offered(ember) and CraftingManager.can_craft(ember) and not CraftingManager.can_craft(sturdy),
			"Leo as %s: now the Ember Stick is offered, and the Sturdy Stick is done" % role)
		var shards: int = ResourceManager.get_count(&"glow_shards")
		_check(CraftingManager.craft(ember, null) and leo.tool_tier == 2 and ResourceManager.get_count(&"glow_shards") == shards - 2
			and leo.get_attack_damage() == damage + 2 and not CraftingManager.can_craft(ember),
			"Leo as %s: the Ember Stick is tier 2 and spends 2 Glow Shards (%d left)" % [role, ResourceManager.get_count(&"glow_shards")])
		if party_hero == &"leo":
			await get_tree().process_frame
			var hud: Node = get_tree().get_first_node_in_group("hud")
			var slots: Dictionary = hud.get("_slots") if hud != null else {}
			var slot: HudWidgets.AbilitySlot = slots.get(&"attack") as HudWidgets.AbilitySlot
			_check(slot != null and slot.pips == 2, "the HUD's attack slot shows tier pips (%d)" % (slot.pips if slot != null else -1))

		# A hit burns: 1 damage a second, 3 ticks, then it is out.
		var beast_def: MobDefinition = load("res://resources/mobs/bramble_beast.tres") as MobDefinition
		var spot: Vector3 = _campfire().global_position + Vector3(9, 0, 0)
		leo.global_position = spot
		var mob: Mob = _spawn_mob(beast_def, spot + Vector3(1.5, 0, 0))
		mob.set_physics_process(false)
		await get_tree().process_frame
		var dealt: int = HeroHits.strike(leo, mob, leo.get_attack_damage())
		var after_hit: int = mob.current_hp
		_check(dealt > 0 and Burn.on(mob) != null, "Leo as %s: the Ember Stick's hit sets the mob burning" % role)
		var ember_burn: ToolTier = leo.tool_effect_tier(&"burn")
		await _wait(ember_burn.burn_seconds() + 0.5)
		_check(after_hit - mob.current_hp == 3 and Burn.on(mob) == null,
			"Leo as %s: the burn ticks 3 times (%d HP)" % [role, after_hit - mob.current_hp])
		var burnt: int = mob.current_hp
		await _wait(1.5)
		_check(mob.current_hp == burnt, "Leo as %s: and then it is out" % role)
		mob.free()

		# Tier 3, the Blaze Stick: a hit's burn splashes onto a mob right
		# next to the target, but not onto one further away.
		var blaze: CraftingRecipe = _recipe(&"blaze_stick")
		ResourceManager.add(&"glow_shards", 4)
		shards = ResourceManager.get_count(&"glow_shards")
		_check(blaze != null and CraftingManager.is_offered(blaze) and CraftingManager.craft(blaze, null) and leo.tool_tier == 3
			and ResourceManager.get_count(&"glow_shards") == shards - 4 and leo.get_attack_damage() == damage + 2,
			"Leo as %s: the Blaze Stick is tier 3 and spends 4 Glow Shards" % role)
		var target: Mob = _spawn_mob(beast_def, spot + Vector3(1.5, 0, 0))
		var beside: Mob = _spawn_mob(beast_def, spot + Vector3(1.5, 0, 1.0))
		var away: Mob = _spawn_mob(beast_def, spot + Vector3(1.5, 0, 4.0))
		for each in [target, beside, away]:
			(each as Mob).set_physics_process(false)
		await get_tree().process_frame
		var beside_hp: int = beside.current_hp
		HeroHits.strike(leo, target, leo.get_attack_damage())
		_check(Burn.on(target) != null and Burn.on(beside) != null and Burn.on(away) == null and beside.current_hp == beside_hp,
			"Leo as %s: the Blaze Stick's burn splashes onto the mob beside the target, not the one further off" % role)
		await _wait(ember_burn.burn_seconds() + 0.5)
		_check(beside_hp - beside.current_hp == 3,
			"Leo as %s: the splashed burn ticks 3 times (%d HP)" % [role, beside_hp - beside.current_hp])
		for each in [target, beside, away]:
			(each as Mob).free()

		# The personal light: off by day, on at night, not inside a torch.
		leo.call("_update_tool_light")
		_check(not leo.is_tool_light_on(), "Leo as %s: no tool light by day" % role)
		while not TimeManager.is_night():
			TimeManager.skip_phase()
		leo.call("_update_tool_light")
		_check(leo.is_tool_light_on() and leo.get_tool_light_range() > leo.tool_effect_tier(&"night_light").light_range,
			"Leo as %s: the Blaze Stick lights him at night, a little wider (%.1f m)" % [role, leo.get_tool_light_range()])
		var torch: Torch = Torch.SCENE.instantiate() as Torch
		get_tree().current_scene.add_child(torch)
		torch.global_position = leo.global_position
		await get_tree().process_frame
		leo.call("_update_tool_light")
		_check(not leo.is_tool_light_on(), "Leo as %s: the light doesn't stack with a torch" % role)
		torch.queue_free()
		table.queue_free()

		# The save holds the tier; Continue brings Leo back at tier 2.
		var data: Dictionary = SaveManager.parse(SaveManager.serialize(RunSession.snapshot()))
		var key: String = leo.save_key()
		_check(int((data[key] as Dictionary).get("tier", -1)) == 3, "Leo as %s: the save holds tier 3" % role)
		await _continue_from(data)
		leo = HeroRoster.node_for(get_tree(), &"leo") as Hero
		_check(leo.tool_tier == 3 and leo.get_attack_damage() == damage + 2 and leo.has_tool_effect(&"burn_splash"),
			"Leo as %s: Continue brings back the Blaze Stick" % role)
		# An old save: `signature: true` and no tier is tier 1.
		(data[key] as Dictionary).erase("tier")
		(data[key] as Dictionary)["signature"] = true
		await _continue_from(data)
		leo = HeroRoster.node_for(get_tree(), &"leo") as Hero
		_check(leo.tool_tier == 1 and leo.get_attack_damage() == damage + 2 and not leo.has_tool_effect(&"burn"),
			"Leo as %s: an old save with signature: true loads as tier 1" % role)


## Nela's Double Sling, as the player's hero and as the
## companion. It is offered only once the Slingshot (tier 1) is owned,
## costs 2 Glow Shards, and every third shot launches two pebbles.
## Then the Glow Sling (tier 3, 4 Glow Shards), whose
## pebble pierces on to the mob behind its target and lights what it hits.
func _run_double_sling_scenario() -> void:
	print("smoke: --- double sling scenario ---")
	for party_hero in [&"nela", &"leo"]:
		await _start_fresh_run(_party(party_hero))
		var nela: Hero = HeroRoster.node_for(get_tree(), &"nela") as Hero
		var role: String = "player" if party_hero == &"nela" else "companion"
		for hero in Party.heroes():
			(hero as Node).set_physics_process(false)
		for building in get_tree().current_scene.find_children("*", "Building", true, false):
			building.set_physics_process(false)
		var table: Building = _spawn_building(&"crafting_table", nela.global_position + Vector3(4, 0, -4))
		for item in [&"wood", &"scrap", &"clay"]:
			ResourceManager.add(item, 10)
		ResourceManager.add(&"glow_shards", 5)
		var sling: CraftingRecipe = _recipe(&"slingshot")
		var double: CraftingRecipe = _recipe(&"double_sling")
		_check(double != null and not CraftingManager.is_offered(double) and not CraftingManager.can_craft(double),
			"Nela as %s: the Double Sling is not offered before the Slingshot" % role)
		if double == null:
			table.queue_free()
			continue
		var beast_def: MobDefinition = load("res://resources/mobs/bramble_beast.tres") as MobDefinition
		var spot: Vector3 = _campfire().global_position + Vector3(9, 0, 0)
		nela.global_position = spot
		var mob: Mob = _spawn_mob(beast_def, spot + Vector3(1.5, 0, 0))
		mob.set_physics_process(false)
		await get_tree().process_frame

		_check(CraftingManager.craft(sling, null) and nela.tool_tier == 1, "Nela as %s: the Slingshot is tier 1" % role)
		var volleys: Array[int] = []
		for i in 3:
			volleys.append(await _pebbles_from(nela, mob))
		_check(volleys == [1, 1, 1], "Nela as %s: the Slingshot fires one pebble a shot (%s)" % [role, volleys])

		var shards: int = ResourceManager.get_count(&"glow_shards")
		_check(CraftingManager.is_offered(double) and CraftingManager.craft(double, null) and nela.tool_tier == 2
			and ResourceManager.get_count(&"glow_shards") == shards - 2 and not CraftingManager.can_craft(double),
			"Nela as %s: the Double Sling is tier 2 and spends 2 Glow Shards" % role)
		volleys.clear()
		for i in 6:
			volleys.append(await _pebbles_from(nela, mob))
		_check(volleys == [1, 1, 2, 1, 1, 2], "Nela as %s: every third shot launches two pebbles (%s)" % [role, volleys])
		await _wait(0.5)
		mob.free()

		# Tier 3, the Glow Sling: a pebble pierces on to the next mob in
		# its line (not to one off to the side) and briefly lights its target.
		var glow: CraftingRecipe = _recipe(&"glow_sling")
		ResourceManager.add(&"glow_shards", 4)
		shards = ResourceManager.get_count(&"glow_shards")
		_check(glow != null and CraftingManager.is_offered(glow) and CraftingManager.craft(glow, null) and nela.tool_tier == 3
			and ResourceManager.get_count(&"glow_shards") == shards - 4 and not CraftingManager.can_craft(glow),
			"Nela as %s: the Glow Sling is tier 3 and spends 4 Glow Shards" % role)
		var front: Mob = _spawn_mob(beast_def, spot + Vector3(1.5, 0, 0))
		var behind: Mob = _spawn_mob(beast_def, spot + Vector3(3.0, 0, 0))
		var aside: Mob = _spawn_mob(beast_def, spot + Vector3(3.0, 0, 2.5))
		for each in [front, behind, aside]:
			(each as Mob).set_physics_process(false)
		await get_tree().process_frame
		var hp: Array[int] = [front.current_hp, behind.current_hp, aside.current_hp]
		_check(await _pebbles_from(nela, front) == 1, "Nela as %s: the Glow Sling's shot is one pebble" % role)
		# Polled, not a fixed wait: the glow is read the frame the hit lands.
		await _wait_until(func() -> bool: return front.current_hp < hp[0], PebbleShot.FLIGHT_SECONDS + 1.0)
		_check(front.current_hp < hp[0] and GlowMark.on(front) != null,
			"Nela as %s: the Glow Sling's pebble hits and lights its target" % role)
		# Every pebble down (the pierce's included) before reading who it hit.
		await _wait_until(func() -> bool: return _pebble_count() == 0, 2.0 * PebbleShot.FLIGHT_SECONDS + 1.0)
		_check(behind.current_hp < hp[1] and aside.current_hp == hp[2],
			"Nela as %s: the pebble pierces on to the mob behind, not the one aside (%d, %d HP lost)"
				% [role, hp[1] - behind.current_hp, hp[2] - aside.current_hp])
		_check(await _wait_until(func() -> bool: return GlowMark.on(front) == null,
			nela.tool_effect_tier(&"glow_hit").glow_seconds + 1.0),
			"Nela as %s: the glow fades" % role)
		for each in [front, behind, aside]:
			(each as Mob).free()
		table.queue_free()


## How many pebbles one attack by `shooter` at `target` launches. They
## leave the sling together at the attack's contact frame, so this waits
## for the first one (counting launches, not pebbles in flight).
func _pebbles_from(shooter: Hero, target: Node3D) -> int:
	var launched: Array[int] = [0]
	var count_launch: Callable = func(node: Node) -> void:
		if node is PebbleShot:
			launched[0] += 1
	var scene: Node = get_tree().current_scene
	scene.child_entered_tree.connect(count_launch)
	shooter.attack(target)
	await _wait_until(func() -> bool: return launched[0] > 0, 1.0)
	scene.child_entered_tree.disconnect(count_launch)
	return launched[0]


func _pebble_count() -> int:
	var count: int = 0
	for child in get_tree().current_scene.get_children():
		if child is PebbleShot and not (child as Node).is_queued_for_deletion():
			count += 1
	return count
