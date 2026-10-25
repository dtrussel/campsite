extends "res://tests/automated/smoke_scenario.gd"

## Hit-stop: as a hero's hit lands, the attacker's and the target's
## visuals freeze for a blink (and the target squashes), while the rest
## of the game (the other hero, another mob) keeps going.


func run() -> void:
	await _run_hit_stop_scenario()


## For Leo and Nela, played and as the companion: each hit freezes the
## attacker and the target but not the bystanders, and both resume. A
## target the hit kills still plays its death.
func _run_hit_stop_scenario() -> void:
	print("smoke: --- hero animation: hit-stop ---")
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
		await _check_hit_stop(player, companion)
		await _check_hit_stop(companion, player)
		await _check_killing_hit(player)


func _check_hit_stop(who: Hero, bystander: Hero) -> void:
	var label: String = _label(who)
	var mob: Mob = await _stage_mob(who)
	# Another mob, far off, walking in on the camp.
	var walker: Mob = _spawn_mob(_beast(), _campfire().global_position + Vector3(-14, 0, 0))
	if not await _wait_until(func() -> bool: return walker.velocity.length() > 0.1, 4.0):
		_fail("%s: the other mob walks in" % label)
	var visual: CharacterVisual = _visual_of(who)
	var target: CharacterVisual = _visual_of(mob)
	var others: Array[CharacterVisual] = [_visual_of(bystander), _visual_of(walker)]
	_check(not visual.is_hit_stopped() and not target.is_hit_stopped(), "%s: no hit-stop before the attack" % label)
	who.attack(mob)
	if not await _wait_until(func() -> bool: return visual.is_hit_stopped(), 2.0):
		_fail("%s: the hit stops the attacker" % label)
		await _clear_staged_mobs()
		return
	_check(target.is_hit_stopped(), "%s: the hit stops the target too" % label)
	_check(not others[0].is_hit_stopped() and not others[1].is_hit_stopped(), "%s: the bystanders are not stopped" % label)
	_check(target.model.scale.y < target.model_scale * 0.97, "%s: the target squashes (%.3f)" % [label, target.model.scale.y / target.model_scale])
	_check(mob.current_hp < mob.definition.max_hp, "%s: the damage applies as the hit lands" % label)
	var frozen: Array = [_pose(visual), _pose(target)]
	var others_before: Array = [_pose(others[0]), _pose(others[1])]
	var walker_from: Vector3 = walker.global_position
	var others_after: Array = others_before
	var held: int = 0
	var still: bool = true
	var full_speed: bool = is_equal_approx(Engine.time_scale, SPEED)
	while true:
		await get_tree().process_frame
		if not visual.is_hit_stopped():
			break
		held += 1
		still = still and _pose(visual) == frozen[0] and _pose(target) == frozen[1]
		full_speed = full_speed and is_equal_approx(Engine.time_scale, SPEED)
		others_after = [_pose(others[0]), _pose(others[1])]
		if held > 600:
			break
	_check(held >= 1 and still, "%s: the attacker and the target hold their pose through the hit-stop (%d frames)" % [label, held])
	_check(full_speed, "%s: the game runs at full speed through the hit-stop" % label)
	_check(others_after[0] != others_before[0], "%s: the other hero keeps animating" % label)
	_check(others_after[1] != others_before[1], "%s: another mob keeps animating" % label)
	# The stop is shorter than a physics tick here (60 per real second,
	# the game at 4x), so the walk shows from the next tick.
	_check(await _wait_until(func() -> bool: return walker.global_position.distance_to(walker_from) > 0.001, 0.2),
		"%s: another mob keeps moving" % label)
	_check(await _wait_until(func() -> bool: return not target.is_hit_stopped(), 1.0), "%s: the target's hit-stop ends" % label)
	_check(await _wait_until(func() -> bool: return _pose(visual) != frozen[0] and _pose(target) != frozen[1], 1.0),
		"%s: the attacker and the target animate again" % label)
	_check(await _wait_until(func() -> bool: return is_equal_approx(target.model.scale.y, target.model_scale), 1.0),
		"%s: the target recovers from the squash" % label)
	await _clear_staged_mobs()
	await _wait_until(func() -> bool: return _pebble_count() == 0, 2.0)


## A target the hit kills is not left frozen: its death plays.
func _check_killing_hit(who: Hero) -> void:
	var label: String = _label(who)
	var mob: Mob = await _stage_mob(who)
	mob.current_hp = 1
	var target: CharacterVisual = _visual_of(mob)
	who.attack(mob)
	_check(await _wait_until(func() -> bool: return not mob.is_alive(), 2.0), "%s: the hit kills the target" % label)
	_check(target.is_hit_stopped(), "%s: the killed target is hit-stopped too" % label)
	var frozen: Array = _pose(target)
	_check(await _wait_until(func() -> bool: return not target.is_hit_stopped() and _pose(target) != frozen, 1.0),
		"%s: the killed target goes on into its death (no frozen corpse)" % label)
	await _clear_staged_mobs()
	await _wait_until(func() -> bool: return _pebble_count() == 0, 2.0)


func _stage_mob(who: Hero) -> Mob:
	var spot: Vector3 = _campfire().global_position + Vector3(9, 0, 0)
	who.global_position = spot
	var mob: Mob = _spawn_mob(_beast(), spot + Vector3(1.5, 0, 0))
	mob.set_physics_process(false)
	await get_tree().process_frame
	return mob


func _beast() -> MobDefinition:
	return load("res://resources/mobs/bramble_beast.tres") as MobDefinition


func _visual_of(node: Node) -> CharacterVisual:
	return node.get_node("Visual") as CharacterVisual


## Every bone's pose, as the animation leaves it this frame.
func _pose(visual: CharacterVisual) -> Array:
	var poses: Array = []
	var skeleton: Skeleton3D = visual.model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return poses
	for bone in skeleton.get_bone_count():
		poses.append(skeleton.get_bone_pose(bone))
	return poses


func _pebble_count() -> int:
	var count: int = 0
	for child in get_tree().current_scene.get_children():
		if child is PebbleShot and not (child as Node).is_queued_for_deletion():
			count += 1
	return count


func _label(who: Hero) -> String:
	return "%s as %s" % [who.hero.id, "companion" if who.is_in_group("companions") else "player"]
