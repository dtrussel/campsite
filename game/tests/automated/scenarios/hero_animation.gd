extends "res://tests/automated/smoke_scenario.gd"

## Hero animation: a hero's attack lands on its contact frame, after a
## short wind-up, in either role.


func run() -> void:
	await _run_contact_frame_scenario()


## For Leo and Nela, played and as the companion: the swing lands, or the
## pebble leaves the sling, at the contact frame and not on the attack's
## first frame. Then the wind-up rules, on the companion (a downed player
## would end the run).
func _run_contact_frame_scenario() -> void:
	print("smoke: --- hero animation: contact frame ---")
	for played in [&"leo", &"nela"]:
		await _start_fresh_run(_party(played))
		var player: Hero = get_tree().get_first_node_in_group("player") as Hero
		var companion: Hero = get_tree().get_first_node_in_group("companions") as Hero
		if player == null or companion == null:
			_fail("party %s: both roles are Heroes" % played)
			continue
		# Hold both still (the test attacks for them), and stop the watch
		# post shooting the staged mobs.
		player.set_physics_process(false)
		companion.set_physics_process(false)
		for building in get_tree().current_scene.find_children("*", "Building", true, false):
			building.set_physics_process(false)
		for who in [player, companion]:
			await _check_contact_frame(who as Hero)
		await _check_wind_up_rules(companion)


func _check_contact_frame(who: Hero) -> void:
	var label: String = _label(who)
	var contact: float = who.hero.attack_contact_time
	_check(contact > 0.0, "%s: the hero's attack has a contact time (%.3f s)" % [label, contact])
	var mob: Mob = await _stage_mob(who)
	var pebbles: int = _pebble_count()
	_check(who.attack(mob), "%s: the attack starts" % label)
	var visual: CharacterVisual = who.get_node("Visual") as CharacterVisual
	var wind_up: float = visual.action_contact_in()
	_check(wind_up > 0.0 and wind_up <= HeroDefinition.WIND_UP_CAP_SECONDS + 0.0001,
		"%s: the visual reports the contact frame %.3f s ahead" % [label, wind_up])
	_check(not _landed(who, mob, pebbles), "%s: nothing lands on the attack's first frame" % label)
	# A long frame can carry the whole wind-up, so this waits on the hit.
	_check(await _wait_until(func() -> bool: return _landed(who, mob, pebbles), 1.0),
		"%s: the %s at the contact frame" % [label, "pebble leaves the sling" if who.hero.ranged else "swing lands"])
	await _clear_staged_mobs()
	await _wait_until(func() -> bool: return _pebble_count() == 0, 2.0)


## Down during the wind-up loses the hit; being hit does not; a melee
## target that left reach is missed quietly.
func _check_wind_up_rules(who: Hero) -> void:
	var label: String = _label(who)

	# Hit during the wind-up: the hit still comes.
	var mob: Mob = await _stage_mob(who)
	var pebbles: int = _pebble_count()
	who.clear_invulnerability()
	who.attack(mob)
	who.take_damage(1)
	_check(await _wait_until(func() -> bool: return _landed(who, mob, pebbles), 1.0),
		"%s: a hero hit during the wind-up still lands the attack" % label)
	await _clear_staged_mobs()
	await _wait_until(func() -> bool: return _pebble_count() == 0, 2.0)

	# Down during the wind-up: no damage from that attack.
	mob = await _stage_mob(who)
	pebbles = _pebble_count()
	who.clear_invulnerability()
	_check(who.attack(mob), "%s: the attack starts" % label)
	who.take_damage(99999)
	_check(who.is_down(), "%s: downed during the wind-up" % label)
	# A check that nothing came: a fixed wait can only end early.
	await _wait(PebbleShot.FLIGHT_SECONDS + 0.6)
	_check(mob.current_hp == mob.definition.max_hp and _pebble_count() == pebbles,
		"%s: a hero downed during the wind-up deals no damage (%d/%d HP, %d pebbles)" % [label, mob.current_hp, mob.definition.max_hp, _pebble_count() - pebbles])
	who.revive(who.max_hp)
	await _clear_staged_mobs()

	# A melee target that steps out of reach during the wind-up is missed.
	if not who.hero.ranged:
		mob = await _stage_mob(who)
		who.attack(mob)
		mob.global_position = who.global_position + Vector3(who.get_attack_range() * 3.0, 0, 0)
		await _wait(0.6)
		_check(mob.current_hp == mob.definition.max_hp, "%s: a target that left reach during the wind-up is missed" % label)
		await _clear_staged_mobs()


func _stage_mob(who: Hero) -> Mob:
	var spot: Vector3 = _campfire().global_position + Vector3(9, 0, 0)
	who.global_position = spot
	var beast_def: MobDefinition = load("res://resources/mobs/bramble_beast.tres") as MobDefinition
	var mob: Mob = _spawn_mob(beast_def, spot + Vector3(1.5, 0, 0))
	mob.set_physics_process(false)
	await get_tree().process_frame
	return mob


## The swing has hit (melee) or a pebble has left the sling (ranged).
func _landed(who: Hero, mob: Mob, pebbles_before: int) -> bool:
	if who.hero.ranged:
		return _pebble_count() > pebbles_before
	return not is_instance_valid(mob) or mob.current_hp < mob.definition.max_hp


func _pebble_count() -> int:
	var count: int = 0
	for child in get_tree().current_scene.get_children():
		if child is PebbleShot and not (child as Node).is_queued_for_deletion():
			count += 1
	return count


func _label(who: Hero) -> String:
	return "%s as %s" % [who.hero.id, "companion" if who.is_in_group("companions") else "player"]
