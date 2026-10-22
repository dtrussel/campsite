extends "res://tests/automated/smoke_scenario.gd"

## Hero select, a run playing Nela, and the Hero interface both
## siblings share in either role: health, levels, gathering, attacks.


func run() -> void:
	await _run_hero_scenario()
	await _run_hero_health_scenario()
	await _run_hero_progress_scenario()
	await _run_hero_gather_scenario()
	await _run_hero_attack_scenario()


## The hero select screen, and a run playing Nela. Each
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
	(player as Hero).attack(imp)
	_check(imp.current_hp == imp_hp, "the pebble has not landed yet")
	await _wait_until(func() -> bool: return not is_instance_valid(imp) or imp.current_hp < imp_hp, PebbleShot.FLIGHT_SECONDS + 1.0)
	_check(not is_instance_valid(imp) or imp.current_hp < imp_hp, "Nela's pebble hit the imp 3.5 m away")
	if is_instance_valid(imp):
		imp.take_damage(999, player)

	# The signature crafts follow the hero, not the role.
	for item in [&"wood", &"scrap"]:
		ResourceManager.add(item, 10)
	var table: Building = _spawn_building(&"crafting_table", Vector3(5, 0, -6))
	var reach: float = (player as Hero).get_attack_range()
	_check(CraftingManager.craft(_recipe(&"slingshot"), player)
		and is_equal_approx((player as Hero).get_attack_range(), reach * nela.tier(1).range_factor), "the slingshot goes to Nela (the player)")
	var damage: int = (companion as Hero).get_attack_damage()
	_check(CraftingManager.craft(_recipe(&"sturdy_stick"), player)
		and (companion as Hero).get_attack_damage() == damage + 2, "the sturdy stick goes to Leo (the companion)")

	# The save remembers the party; Continue plays Nela again.
	var data: Dictionary = RunSession.snapshot()
	_check(String(data["party"]["hero"]) == "nela" and String(data["party"]["companion"]) == "leo", "the save holds the party")
	var legacy: Dictionary = data.duplicate(true)
	legacy.erase("party")
	_check(GameManager.party_of(legacy)["hero"] == &"leo", "older saves without a party are Leo with Nela")
	table.queue_free()
	GameManager.set_party(&"leo")  # Continue takes the party from the save
	await _continue_from(data)
	player = get_tree().get_first_node_in_group("player")
	_check(player.is_in_group(HeroRoster.group_for(&"nela")) and bool(player.get("has_signature")),
		"continued as Nela, slingshot and all")
	GameManager.set_party(&"leo")


## Leo and Nela take hits, heal and go down the same way
## in both roles, through the Hero interface. The companion revives at
## dawn; the player's hero going down ends the run.
func _run_hero_health_scenario() -> void:
	print("smoke: --- hero health scenario ---")
	for hero_id in [&"leo", &"nela"]:
		GameManager.set_party(hero_id)
		await _start_fresh_run()
		var player: Hero = get_tree().get_first_node_in_group("player") as Hero
		var companion: Hero = get_tree().get_first_node_in_group("companions") as Hero
		_check(player != null and companion != null, "party %s: both roles are Heroes" % hero_id)
		if player == null or companion == null:
			continue
		for who in [player, companion]:
			_check_hero_health(who as Hero)
		# The companion goes down, then gets back up at dawn.
		var downs: Array[bool] = []
		companion.down_changed.connect(func(is_down: bool) -> void: downs.append(is_down))
		companion.clear_invulnerability()
		companion.take_damage(9999)
		var label: String = "%s as companion" % _hero_id(companion)
		_check(companion.is_down() and companion.current_hp == 0 and downs == [true],
			"%s: going down emits down_changed(true) (%s)" % [label, downs])
		companion.clear_invulnerability()
		companion.take_damage(5)
		companion.heal(5)
		_check(companion.current_hp == 0, "%s: no hits or heals while down" % label)
		var t: int = 0
		while companion.is_down() and t < 4:
			TimeManager.skip_phase()
			t += 1
		_check(not companion.is_down() and companion.current_hp == companion.max_hp and downs == [true, false],
			"%s: revives at dawn at full HP (%d/%d, %s)" % [label, companion.current_hp, companion.max_hp, downs])
		# The player's hero going down ends the run.
		var player_downs: Array[bool] = []
		player.down_changed.connect(func(is_down: bool) -> void: player_downs.append(is_down))
		player.clear_invulnerability()
		player.take_damage(9999)
		label = "%s as player" % _hero_id(player)
		_check(player.is_down() and player_downs == [true], "%s: going down emits down_changed(true)" % label)
		_check(GameManager.run_state == GameManager.RunState.LOST and GameManager.end_trigger == &"loss_hero",
			"%s: being down ends the run (%s)" % [label, GameManager.end_reason])
	GameManager.set_party(&"leo")


## A level-up applies the stat bumps, then emits
## `leveled(level)` once; the perk picker (player) and the auto-pick
## (companion) come after it, and a restored save emits it quietly.
func _run_hero_progress_scenario() -> void:
	print("smoke: --- hero progress scenario ---")
	for hero_id in [&"leo", &"nela"]:
		GameManager.set_party(hero_id)
		await _start_fresh_run(_config(5.0))  # keep the player's picker open
		var player: Hero = get_tree().get_first_node_in_group("player") as Hero
		var companion: Hero = get_tree().get_first_node_in_group("companions") as Hero
		_check(player != null and companion != null, "party %s: both roles are Heroes" % hero_id)
		if player == null or companion == null:
			continue
		for who in [player, companion]:
			_check_hero_level_up(who as Hero)
		PerkManager.close_picker()
		# A restored save replays the level-up: stats and `leveled`, no picker.
		await _start_fresh_run(_config(5.0))
		player = get_tree().get_first_node_in_group("player") as Hero
		var levels: Array[int] = []
		var on_level: Callable = func(who: Node, level: int) -> void:
			if Party.role_of(who) == Party.PLAYER:
				levels.append(level)
		var before: int = player.max_hp
		var stats: CharacterStatsDefinition = ProgressionManager.get_stats(player)
		ProgressionManager.level_up.connect(on_level)
		await _continue_with_xp(Party.PLAYER, stats.xp_threshold_for_level(2), _config(5.0))
		ProgressionManager.level_up.disconnect(on_level)
		player = Party.player_hero()
		_check(levels == [2] and player.max_hp == before + stats.max_health_per_level and not PerkManager.is_picking(),
			"party %s: a restored level-up applies its stats with no picker (%s)" % [hero_id, levels])
	GameManager.set_party(&"leo")


## Both heroes gather, cancel and finish through the Hero
## interface in each role; the companion's gather task never sticks on
## a resource; Party names the right heroes after a hero swap.
func _run_hero_gather_scenario() -> void:
	print("smoke: --- hero gather scenario ---")
	for hero_id in [&"leo", &"nela"]:
		GameManager.set_party(hero_id)
		await _start_fresh_run()
		var player: Hero = get_tree().get_first_node_in_group("player") as Hero
		var companion: Companion = get_tree().get_first_node_in_group("companions") as Companion
		_check(player != null and companion != null, "party %s: both roles are Heroes" % hero_id)
		if player == null or companion == null:
			continue
		_check_party(hero_id, player, companion)
		player.set("auto_attack", false)
		companion.set_task(Companion.Task.IDLE)
		for who in [player, companion]:
			await _check_hero_gather(who as Hero)
		await _check_companion_gather_task(companion)
	GameManager.set_party(&"leo")


## Leo and Nela attack the same way in both roles, through
## the Hero interface: damage and reach come from the definition (by
## role), an attack starts the cooldown and lands, and the signature
## tool changes damage and reach.
func _run_hero_attack_scenario() -> void:
	print("smoke: --- hero attack scenario ---")
	for hero_id in [&"leo", &"nela"]:
		GameManager.set_party(hero_id)
		await _start_fresh_run()
		var player: Hero = get_tree().get_first_node_in_group("player") as Hero
		var companion: Hero = get_tree().get_first_node_in_group("companions") as Hero
		if player == null or companion == null:
			_fail("party %s: both roles are Heroes" % hero_id)
			continue
		# Hold both still (the test attacks for them), and stop the watch
		# post shooting the staged mob.
		player.set_physics_process(false)
		companion.set_physics_process(false)
		for building in get_tree().current_scene.find_children("*", "Building", true, false):
			building.set_physics_process(false)
		for who in [player, companion]:
			await _check_hero_attack(who as Hero)
	GameManager.set_party(&"leo")


## A hit lowers HP, the invulnerability window blocks a second one, and
## a heal raises it again.
func _check_hero_health(who: Hero) -> void:
	var label: String = "%s as %s" % [_hero_id(who), "player" if who.is_in_group("player") else "companion"]
	who.heal(who.max_hp)
	who.clear_invulnerability()
	var full: int = who.current_hp
	who.take_damage(6)
	var hit: int = who.current_hp
	_check(hit < full and who.is_invulnerable(), "%s: a hit lowers HP (%d -> %d)" % [label, full, hit])
	who.take_damage(6)
	_check(who.current_hp == hit, "%s: the invulnerability window blocks a second hit" % label)
	who.heal(3)
	_check(who.current_hp == mini(who.max_hp, hit + 3), "%s: a heal raises HP (%d -> %d)" % [label, hit, who.current_hp])
	_check(not who.is_down(), "%s: still up" % label)


func _hero_id(who: Node) -> StringName:
	var definition: HeroDefinition = who.get("hero") as HeroDefinition
	return definition.id if definition != null else &"?"


## Levels `who` up once: max HP has risen by the per-level bump before
## `leveled(2)` fires, and the perk manager (the player's picker, the
## companion's own pick) reacts after the new HP is in.
func _check_hero_level_up(who: Hero) -> void:
	var as_player: bool = who.is_in_group("player")
	var label: String = "%s as %s" % [_hero_id(who), "player" if as_player else "companion"]
	var stats: CharacterStatsDefinition = ProgressionManager.get_stats(who)
	var before: int = who.max_hp
	var seen: Array = []  # [level, max_hp] at each `leveled`
	var reacted: Array = []  # max_hp when the perk manager reacted
	var on_leveled: Callable = func(level: int) -> void: seen.append([level, who.max_hp])
	var on_picker: Callable = func(character: Node, _picker: PerkPicker) -> void:
		if character == who:
			reacted.append(who.max_hp)
	var on_taken: Callable = func(character: Node, _perk: PerkDefinition) -> void:
		if character == who:
			reacted.append(who.max_hp)
	who.leveled.connect(on_leveled)
	PerkManager.picker_opened.connect(on_picker)
	PerkManager.perk_taken.connect(on_taken)
	ProgressionManager.award_xp(who, ProgressionManager.get_xp_to_next_level(who), &"test")
	who.leveled.disconnect(on_leveled)
	PerkManager.picker_opened.disconnect(on_picker)
	PerkManager.perk_taken.disconnect(on_taken)
	var raised: int = before + stats.max_health_per_level
	_check(seen.size() == 1 and int(seen[0][0]) == 2, "%s: a level-up emits leveled(2) once (%s)" % [label, seen])
	_check(seen.size() == 1 and int(seen[0][1]) == raised,
		"%s: max HP rose before leveled fired (%d -> %s)" % [label, before, seen])
	_check(reacted == [raised], "%s: the perk manager reacts with the new HP in (%s)" % [label, reacted])
	if as_player:
		_check(PerkManager.is_picking(), "%s: the picker opens on level-up" % label)
	else:
		_check(PerkManager.perks_of(who).size() == 1,
			"%s: the companion picks a card by itself" % label)


## Party: the player's hero, the companion, each one's other hero, both
## heroes and their roles, for the party just started.
func _check_party(hero_id: StringName, player: Hero, companion: Hero) -> void:
	_check(Party.player_hero() == player and _hero_id(Party.player_hero()) == hero_id,
		"party %s: Party.player_hero() is %s" % [hero_id, hero_id])
	_check(Party.companion() == companion and _hero_id(Party.companion()) == GameManager.companion_id,
		"party %s: Party.companion() is %s" % [hero_id, GameManager.companion_id])
	_check(Party.other(player) == companion and Party.other(companion) == player and Party.other(null) == null,
		"party %s: each hero's other hero is their sibling" % hero_id)
	var both: Array[Hero] = Party.heroes()
	_check(both.size() == 2 and both[0] == player and both[1] == companion, "party %s: Party.heroes() is both, player first" % hero_id)
	_check(Party.role_of(player) == Party.PLAYER and Party.role_of(companion) == Party.COMPANION
		and Party.role_of(_campfire()) == &"", "party %s: Party.role_of() names each role" % hero_id)


## Start, cancel, start again and finish on a berry bush.
func _check_hero_gather(who: Hero) -> void:
	var label: String = "%s as %s" % [_hero_id(who), Party.role_of(who)]
	var bush: ResourceNode = _find_resource_node(&"berries")
	if bush == null:
		_fail("%s: no berry bush to gather" % label)
		return
	who.global_position = bush.global_position + Vector3(1.2, 0, 0)
	await _wait(0.1)
	var finished: Array[ResourceNode] = []
	var on_finished: Callable = func(node: ResourceNode) -> void: finished.append(node)
	who.gather_finished.connect(on_finished)
	_check(who.start_gather(bush) and who.is_gathering() and who.gather_target() == bush,
		"%s: starts gathering a bush" % label)
	who.cancel_gather()
	_check(not who.is_gathering() and who.gather_target() == null, "%s: cancels the gather" % label)
	await _wait(bush.gather_seconds_for(who) + 0.3)
	_check(finished.is_empty(), "%s: a cancelled gather never finishes" % label)
	var berries: int = ResourceManager.get_count(&"berries")
	_check(who.start_gather(bush), "%s: the bush is free again after the cancel" % label)
	var t: float = 0.0
	while finished.is_empty() and t < bush.gather_seconds_for(who) + 2.0:
		await _wait(0.1)
		t += 0.1
	_check(finished == [bush] and not who.is_gathering() and ResourceManager.get_count(&"berries") > berries,
		"%s: the gather finishes and pays out (%.1fs)" % [label, t])
	who.gather_finished.disconnect(on_finished)


## On the gather task the companion gathers, finishes, and goes on to
## gather again instead of standing stuck at the old node; a task change
## cancels.
func _check_companion_gather_task(companion: Companion) -> void:
	var label: String = "%s as companion" % _hero_id(companion)
	var finished: Array[ResourceNode] = []
	var on_finished: Callable = func(node: ResourceNode) -> void: finished.append(node)
	companion.gather_finished.connect(on_finished)
	# The player's hero is on the bush right by her: she goes elsewhere.
	var player: Hero = Party.player_hero()
	var bush: ResourceNode = _find_resource_node(&"berries")
	player.global_position = bush.global_position + Vector3(1.2, 0, 0)
	companion.global_position = bush.global_position + Vector3(-1.2, 0, 0)
	await _wait(0.1)
	_check(player.start_gather(bush), "%s: the player's hero gathers the bush next to her" % label)
	companion.set_task(Companion.Task.GATHER_NEAREST)
	var t: float = 0.0
	while not companion.is_gathering() and t < 10.0:
		await _wait(0.2)
		t += 0.2
	_check(companion.is_gathering() and companion.gather_target() != bush,
		"%s: the gather task skips the bush the other hero is on (%.1fs)" % [label, t])
	player.cancel_gather()
	t = 0.0
	while finished.size() < 2 and t < 30.0:
		await _wait(0.2)
		t += 0.2
	_check(finished.size() >= 2, "%s: the gather task finishes a node and goes on gathering (%d in %.1fs)" % [label, finished.size(), t])
	t = 0.0
	while not companion.is_gathering() and t < 10.0:
		await _wait(0.2)
		t += 0.2
	_check(companion.is_gathering(), "%s: and keeps gathering" % label)
	companion.set_task(Companion.Task.IDLE)
	_check(not companion.is_gathering(), "%s: a task change cancels the gather" % label)
	companion.gather_finished.disconnect(on_finished)


func _check_hero_attack(who: Hero) -> void:
	var as_companion: bool = who.is_in_group("companions")
	var label: String = "%s as %s" % [_hero_id(who), "companion" if as_companion else "player"]
	var definition: HeroDefinition = who.hero
	var reach: float = definition.companion_attack_range if as_companion else definition.attack_range
	var damage: int = definition.stats.base_attack_damage
	_check(who.get_attack_damage() == damage and is_equal_approx(who.get_attack_range(), reach),
		"%s: damage %d and reach %.2f match the definition (%d, %.2f)" % [label, who.get_attack_damage(), who.get_attack_range(), damage, reach])
	_check(who.tool_tier == 0, "%s: no tool tier yet" % label)

	# One attack: the cooldown starts and the hit lands.
	var spot: Vector3 = _campfire().global_position + Vector3(9, 0, 0)
	who.global_position = spot
	var beast_def: MobDefinition = load("res://resources/mobs/bramble_beast.tres") as MobDefinition
	var mob: Mob = _spawn_mob(beast_def, spot + Vector3(1.5, 0, 0))
	mob.set_physics_process(false)
	await get_tree().process_frame
	_check(who.is_attack_ready() and not who.is_attacking(), "%s: ready, and not attacking yet" % label)
	_check(who.attack(mob) and not who.is_attack_ready(), "%s: an attack starts the cooldown" % label)
	_check(who.is_attacking(), "%s: attacking while the cooldown runs" % label)
	await _wait(1.2)
	_check(mob.current_hp < beast_def.max_hp, "%s: the attack lands (%d/%d HP)" % [label, mob.current_hp, beast_def.max_hp])
	if not as_companion:
		# The pointer commands ask the player's hero whether it is attacking:
		# an attack command counts too. The last target is freed (the
		# cooldown is frozen with physics off), so only the command counts.
		var gone: Mob = mob
		mob = null
		gone.free()
		mob = _spawn_mob(beast_def, spot + Vector3(1.5, 0, 0))
		mob.set_physics_process(false)
		(who as Node).call("command_attack", mob)
		var attacking: bool = who.is_attacking()
		(who as Node).call("stop_commands")
		_check(attacking and not who.is_attacking(), "%s: an attack command is attacking, until stopped" % label)
	await _clear_staged_mobs()

	# The signature tool: its damage bonus and its range factor, by role.
	var first: ToolTier = definition.tier(1)
	var factor: float = first.companion_range_factor if as_companion else first.range_factor
	who.apply_signature()
	_check(who.has_signature and who.tool_tier == 1 and who.get_attack_damage() == damage + first.damage_bonus
		and is_equal_approx(who.get_attack_range(), reach * factor),
		"%s: the %s makes damage %d and reach %.2f" % [label, first.label, who.get_attack_damage(), who.get_attack_range()])
	who.apply_signature()
	_check(who.tool_tier == 1 and who.get_attack_damage() == damage + first.damage_bonus, "%s: the signature applies once" % label)
