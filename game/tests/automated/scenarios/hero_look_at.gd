extends "res://tests/automated/smoke_scenario.gd"

## The head look-at: for Leo and Nela, as the player's hero and as the
## companion, the head and chest turn toward the attack target while
## fighting and toward the resource while gathering, never past the cap.
## The heroes' AI and movement are held still (physics off), so only the
## look turns them.

## The cap on the head and chest's combined turn (degrees), plus a
## little for the lean and the clip's own sway.
const CAP_DEGREES: float = 60.0
const SLACK_DEGREES: float = 4.0


func run() -> void:
	print("smoke: --- hero look-at scenario ---")
	for party_hero in [&"leo", &"nela"]:
		await _start_fresh_run(_party(party_hero))
		for hero in Party.heroes():
			(hero as Node).set_physics_process(false)
		for hero in Party.heroes():
			var role: String = "player" if Party.role_of(hero) == Party.PLAYER else "companion"
			var label: String = "%s as %s" % [hero.hero.id, role]
			await _check_fight_look(hero, label)
			await _check_gather_look(hero, label)


## A mob 90 degrees to the hero's side: the head turns that way, up to
## the cap; one 30 degrees off: the head turns about 30 degrees.
func _check_fight_look(hero: Hero, label: String) -> void:
	var visual: CharacterVisual = hero.get_node("Visual") as CharacterVisual
	var spot: Vector3 = _campfire().global_position + Vector3(8, 0, 6)
	hero.global_position = spot
	var mob: Mob = _spawn_mob(load("res://resources/mobs/bramble_beast.tres") as MobDefinition, spot + Vector3(1.6, 0, 0))
	mob.set_physics_process(false)
	await get_tree().process_frame
	_check(hero.attack(mob), "%s: attacks the staged mob" % label)
	# Facing +Z, the mob (at +X) is +90 degrees around the up axis.
	visual.face_instantly(Vector3(0, 0, 1))
	var turned: bool = await _wait_until(func() -> bool: return visual.look_turn_degrees() > CAP_DEGREES - 6.0, 2.0)
	_check(visual.look_focus() == mob and turned and visual.look_turn_degrees() <= CAP_DEGREES + SLACK_DEGREES,
		"%s: fighting, the head turns toward the mob to the side, capped (%.1f deg)" % [label, visual.look_turn_degrees()])
	# Facing 60 degrees round from +Z, the mob is +30 degrees off.
	visual.face_instantly(Vector3(sin(deg_to_rad(60.0)), 0, cos(deg_to_rad(60.0))))
	var settled: bool = await _wait_until(func() -> bool: return absf(visual.look_turn_degrees() - 30.0) < 6.0, 2.0)
	_check(settled, "%s: fighting, a mob 30 deg off turns the head about 30 deg (%.1f)" % [label, visual.look_turn_degrees()])
	await _clear_staged_mobs()


## A resource node to the hero's other side while gathering: the head
## turns the other way, toward it.
func _check_gather_look(hero: Hero, label: String) -> void:
	var visual: CharacterVisual = hero.get_node("Visual") as CharacterVisual
	var node: ResourceNode = _find_resource_node(&"wood")
	hero.global_position = node.global_position + Vector3(-1.4, 0, 0)
	await get_tree().process_frame
	_check(hero.start_gather(node), "%s: starts gathering wood" % label)
	# Facing -Z, the tree (at +X) is -90 degrees around the up axis.
	visual.face_instantly(Vector3(0, 0, -1))
	var turned: bool = await _wait_until(func() -> bool: return visual.look_turn_degrees() < -(CAP_DEGREES - 6.0), 2.0)
	_check(visual.look_focus() == node and turned and visual.look_turn_degrees() >= -(CAP_DEGREES + SLACK_DEGREES),
		"%s: gathering, the head turns toward the tree, capped (%.1f deg)" % [label, visual.look_turn_degrees()])
	hero.cancel_gather()
