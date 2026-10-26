extends "res://tests/automated/smoke_scenario.gd"

## Hero animation: a hero's attack lands on its contact frame, after a
## short wind-up, in either role. As the hit lands the attacker and the
## target freeze for a blink (the hit-stop) while the rest of the game
## runs on. The head turns toward the attack target and the work. A hero
## left idle fidgets now and then, and moving cancels the fidget. A hero
## going down holds the down pose, and gets up from it. A hero's spring
## chains (hair, pack, lantern) swing out after a sudden turn and settle
## back, in either role and on hero select, and so do Mum's, whose story
## clips still play. A kid's face blinks, winces at a hit, beams in a
## cheer and looks dazed while down; Mum blinks.

## A chain tip this far (m) from where the animation puts it has swung.
const SPRING_SWUNG: float = 0.04
## Within this (m) it has settled (the idle's own sway lags a little).
const SPRING_SETTLED: float = 0.025
## Game seconds a chain may take to settle after the turn.
const SPRING_SETTLE_SECONDS: float = 2.5
## Game seconds an attack may take to land: the wind-up is at most
## WIND_UP_CAP_SECONDS, but a stalled frame is longer than that.
const LAND_SECONDS: float = 1.0
## The look's slack over its cap (degrees), for the lean and the clip's
## own sway; and how near its goal (degrees) the turn counts as there.
const LOOK_SLACK_DEGREES: float = 4.0
const LOOK_NEAR_DEGREES: float = 6.0
## A mob this far (degrees) off the hero's facing, inside the cap, turns
## the head about that far.
const LOOK_OFF_DEGREES: float = 30.0
## Game seconds the look may take to ease round.
const LOOK_SECONDS: float = 2.0


func run() -> void:
	await _run_contact_frame_scenario()
	await _run_hit_stop_scenario()
	await _run_look_at_scenario()
	await _run_fidget_scenario()
	await _run_down_scenario()
	await _run_spring_scenario()
	await _run_face_scenario()


## Each kid, played and as the companion: the face blinks now and then;
## a hit shows the hurt face and then neutral again; a cheer shows the
## happy face; a companion going down looks dazed until it is back up.
## Mum blinks too.
func _run_face_scenario() -> void:
	print("smoke: --- hero animation: faces ---")
	for played in [&"leo", &"nela"]:
		await _start_fresh_run(_party(played))
		var companion: Hero = get_tree().get_first_node_in_group("companions") as Hero
		if companion == null:
			_fail("party %s: the companion is a Hero" % played)
			continue
		var visual: CharacterVisual = companion.get_node("Visual") as CharacterVisual
		var label: String = _label(companion)
		companion.take_damage(companion.max_hp + 10)
		_check(await _wait_until(func() -> bool: return visual.face_shown() == &"dazed", 1.0),
			"%s: down, it looks dazed (%s)" % [label, visual.face_shown()])
		await _wait(0.5)
		_check(visual.face_shown() == &"dazed", "%s: and still dazed while down" % label)
		companion.revive(companion.max_hp)
		_check(await _wait_until(func() -> bool: return _neutral(visual), 1.0),
			"%s: back up, the daze is gone (%s)" % [label, visual.face_shown()])
		for who in Party.heroes():
			var hero: Hero = who as Hero
			hero.set_physics_process(false)
			var hero_visual: CharacterVisual = hero.get_node("Visual") as CharacterVisual
			hero_visual.set_locomotion(0.0)
			await _check_face(hero, hero_visual, _label(hero))
	var mum: CharacterVisual = MumArrival.make_visual()
	add_child(mum)
	await get_tree().process_frame
	_check(_neutral(mum), "Mum: her face shows (%s)" % mum.face_shown())
	_check(await _wait_until(func() -> bool: return mum.blinks_shown > 0, BlinkScheduler.GAP_MAX + 1.0),
		"Mum: she blinks")
	mum.queue_free()
	await get_tree().process_frame


func _neutral(visual: CharacterVisual) -> bool:
	return visual.face_shown() == FaceAtlas.NEUTRAL or visual.face_shown() == FaceAtlas.BLINK


func _check_face(hero: Hero, visual: CharacterVisual, label: String) -> void:
	_check(_neutral(visual), "%s: the face shows, neutral (%s)" % [label, visual.face_shown()])
	var before: int = visual.blinks_shown
	_check(await _wait_until(func() -> bool: return visual.blinks_shown > before, BlinkScheduler.GAP_MAX + 1.0),
		"%s: blinks within %.0f s" % [label, BlinkScheduler.GAP_MAX])
	# An action's end is timed in real seconds (CharacterVisual), and the
	# smoke test runs the game faster than that.
	await _wait_until(func() -> bool: return not visual.is_in_action(), 3.0 * Engine.time_scale)
	hero.take_damage(1)
	_check(await _wait_until(func() -> bool: return visual.face_shown() == &"hurt", 1.0),
		"%s: hit, it winces (%s)" % [label, visual.face_shown()])
	_check(await _wait_until(func() -> bool: return _neutral(visual), 3.0 * Engine.time_scale),
		"%s: and is neutral again after the hit (%s)" % [label, visual.face_shown()])
	visual.play_action(&"cheer")
	_check(await _wait_until(func() -> bool: return visual.face_shown() == &"happy", 1.0),
		"%s: cheering, it beams (%s)" % [label, visual.face_shown()])
	_check(await _wait_until(func() -> bool: return _neutral(visual), 4.0 * Engine.time_scale),
		"%s: and is neutral again after the cheer (%s)" % [label, visual.face_shown()])


## For Leo and Nela, played and as the companion: the swing lands, or the
## pebble leaves the sling, at the contact frame and not on the attack's
## first frame. Then the wind-up rules in both roles; the player's hero
## goes last, as going down ends its run.
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
		await _check_wind_up_rules(player)


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
	_check(await _wait_until(func() -> bool: return _landed(who, mob, pebbles), LAND_SECONDS),
		"%s: the %s at the contact frame" % [label, "pebble leaves the sling" if who.hero.ranged else "swing lands"])
	await _clear_staged_mobs()
	await _wait_until(func() -> bool: return _pebble_count() == 0, 2.0)


## Being hit during the wind-up does not lose the hit; a melee target
## that left reach or died by the contact frame is missed quietly; going
## down loses the hit (last: the player's hero going down ends the run).
func _check_wind_up_rules(who: Hero) -> void:
	var label: String = _label(who)
	var visual: CharacterVisual = who.get_node("Visual") as CharacterVisual

	# Hit during the wind-up: the hit still comes.
	var mob: Mob = await _stage_mob(who)
	var pebbles: int = _pebble_count()
	who.clear_invulnerability()
	who.attack(mob)
	who.take_damage(1)
	_check(await _wait_until(func() -> bool: return _landed(who, mob, pebbles), LAND_SECONDS),
		"%s: a hero hit during the wind-up still lands the attack" % label)
	await _clear_staged_mobs()
	await _wait_until(func() -> bool: return _pebble_count() == 0, 2.0)

	if not who.hero.ranged:
		# A melee target that steps out of reach during the wind-up is missed.
		mob = await _stage_mob(who)
		who.attack(mob)
		mob.global_position = who.global_position + Vector3(who.get_attack_range() * 3.0, 0, 0)
		_check(await _wait_until(func() -> bool: return not who.is_winding_up(), LAND_SECONDS)
			and mob.current_hp == mob.definition.max_hp,
			"%s: a target that left reach during the wind-up is missed" % label)
		await _clear_staged_mobs()

		# A melee target that dies during the wind-up is missed quietly: no
		# swing, so no hit-stop on the hero.
		mob = await _stage_mob(who)
		var stops: int = visual.hit_stops
		who.attack(mob)
		mob.take_damage(mob.current_hp, null)
		_check(not mob.is_alive(), "%s: the target dies during the wind-up" % label)
		_check(await _wait_until(func() -> bool: return not who.is_winding_up(), LAND_SECONDS)
			and visual.hit_stops == stops,
			"%s: a target that died during the wind-up is missed quietly (%d hit-stops)" % [label, visual.hit_stops - stops])
		await _clear_staged_mobs()

	# Down during the wind-up: no damage from that attack.
	mob = await _stage_mob(who)
	pebbles = _pebble_count()
	who.clear_invulnerability()
	_check(who.attack(mob), "%s: the attack starts" % label)
	who.take_damage(99999)
	_check(who.is_down(), "%s: downed during the wind-up" % label)
	_check(not who.is_winding_up(), "%s: going down drops the wind-up" % label)
	# A check that nothing came: a fixed wait can only end early.
	await _wait(PebbleShot.FLIGHT_SECONDS + 0.6)
	_check(mob.current_hp == mob.definition.max_hp and _pebble_count() == pebbles,
		"%s: a hero downed during the wind-up deals no damage (%d/%d HP, %d pebbles)" % [label, mob.current_hp, mob.definition.max_hp, _pebble_count() - pebbles])
	who.revive(who.max_hp)
	await _clear_staged_mobs()


func _stage_mob(who: Hero, offset: Vector3 = Vector3(1.5, 0, 0)) -> Mob:
	var spot: Vector3 = _campfire().global_position + Vector3(9, 0, 0)
	who.global_position = spot
	var mob: Mob = _spawn_mob(_beast(), spot + offset)
	mob.set_physics_process(false)
	await get_tree().process_frame
	return mob


func _beast() -> MobDefinition:
	return load("res://resources/mobs/bramble_beast.tres") as MobDefinition


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


## Leo played, Nela the companion, both left standing: each plays one of
## their own fidgets after a wait in FidgetScheduler's range. Moving
## cancels a fidget back to locomotion.
func _run_fidget_scenario() -> void:
	print("smoke: --- hero animation: idle fidgets ---")
	await _start_fresh_run(_party(&"leo"))
	var player: Hero = get_tree().get_first_node_in_group("player") as Hero
	var companion: Hero = get_tree().get_first_node_in_group("companions") as Hero
	if player == null or companion == null:
		_fail("fidgets: both roles are Heroes")
		return
	# The companion stands where it is (it would follow, fetch and work).
	companion.set_physics_process(false)
	(companion.get_node("Visual") as CharacterVisual).set_locomotion(0.0)
	var longest: float = FidgetScheduler.GAP_MAX + 2.0
	for who in [player, companion]:
		var label: String = _label(who)
		var visual: CharacterVisual = who.get_node("Visual") as CharacterVisual
		_check(not who.hero.fidgets.is_empty(), "%s: the hero lists fidgets (%s)" % [label, who.hero.fidgets])
		if not await _wait_until(func() -> bool: return visual.fidgets_played > 0, longest):
			_fail("%s: left idle, the hero fidgets within %.0f s" % [label, longest])
			continue
		_check(who.hero.fidgets.has(visual.last_fidget), "%s: plays one of its own fidgets (%s)" % [label, visual.last_fidget])
		# The wait can overshoot by the frame the fidget fires on, and the
		# stalled pass's long frames are 0.6 game seconds at its speed.
		_check(visual.last_fidget_wait >= FidgetScheduler.GAP_MIN - 0.05 and visual.last_fidget_wait <= FidgetScheduler.GAP_MAX + 0.75,
			"%s: after %.2f s idle, in the %.0f-%.0f s range" % [label, visual.last_fidget_wait, FidgetScheduler.GAP_MIN,
				FidgetScheduler.GAP_MAX])

	# Moving cancels a fidget: wait for the player's next one, then walk.
	var visual: CharacterVisual = player.get_node("Visual") as CharacterVisual
	if not await _wait_until(func() -> bool: return visual.fidget_playing() != &"", longest + 4.0):
		_fail("fidgets: the player fidgets again")
		return
	player.command_move(player.global_position + Vector3(8, 0, 0))
	_check(await _wait_until(func() -> bool: return visual.is_moving(), 1.0), "fidgets: the player sets off")
	# The visual cancels the fidget on the frame it starts moving; the
	# fade back to locomotion then takes 0.18 s (a stalled frame can
	# carry a short wait past it before the tree steps, so allow more).
	_check(visual.fidget_playing() == &"", "fidgets: moving cancels the fidget")
	_check(await _wait_until(func() -> bool: return visual.active_action_layer() == "", 1.5),
		"fidgets: and it fades back to locomotion")
	player.stop_commands()


## Each kid as the companion (the player's hero going down ends the
## run): going down plays the death clip through and holds its last
## frame; revived, as at dawn, the kid plays the getup from there and
## stands.
func _run_down_scenario() -> void:
	print("smoke: --- hero animation: down and back up ---")
	for played in [&"nela", &"leo"]:
		await _start_fresh_run(_party(played))
		var companion: Hero = get_tree().get_first_node_in_group("companions") as Hero
		if companion == null:
			_fail("party %s: the companion is a Hero" % played)
			continue
		var label: String = _label(companion)
		var visual: CharacterVisual = companion.get_node("Visual") as CharacterVisual
		var down_clip: String = String(companion.hero.clips[&"death"])
		companion.take_damage(companion.max_hp + 10)
		_check(companion.is_down(), "%s: goes down" % label)
		if not await _wait_until(func() -> bool: return visual.held_clip() == down_clip, 3.0):
			_fail("%s: going down plays %s through and holds its last frame (holds '%s')"
				% [label, down_clip, visual.held_clip()])
			continue
		await _wait(0.5)
		_check(companion.is_down() and visual.held_clip() == down_clip,
			"%s: still down on the last frame of %s half a second later" % [label, down_clip])
		companion.revive(companion.max_hp)
		_check(visual.playing_action() == &"getup" and visual.held_clip() == "",
			"%s: revived, it leaves the down pose with its getup (%s)" % [label, visual.playing_action()])
		# An action's end is timed in real seconds (CharacterVisual), and
		# the smoke test runs the game faster than that.
		var player: AnimationPlayer = visual.model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var getup: float = player.get_animation(String(companion.hero.clips[&"getup"])).length
		_check(await _wait_until(func() -> bool: return visual.playing_action() == &"" and not companion.is_down(),
			(getup + 1.0) * Engine.time_scale), "%s: and is up when the getup ends" % label)


## Each hero with spring chains (Leo has his), played and as the
## companion, and on hero select: standing still, a sudden 180-degree
## turn swings a chain's tip away from its animated place, and it
## settles back in time.
func _run_spring_scenario() -> void:
	print("smoke: --- hero animation: spring chains ---")
	var leo: HeroDefinition = HeroRoster.get_hero(&"leo")
	_check(leo != null and not leo.spring_chains.is_empty(), "Leo has spring chains")
	var nela: HeroDefinition = HeroRoster.get_hero(&"nela")
	_check(nela != null and not nela.spring_chains.is_empty(), "Nela has spring chains")
	for played in [&"leo", &"nela"]:
		await _start_fresh_run(_party(played))
		for who in Party.heroes():
			var hero: Hero = who as Hero
			hero.set_physics_process(false)
			var visual: CharacterVisual = hero.get_node("Visual") as CharacterVisual
			visual.set_locomotion(0.0)
			if not hero.hero.spring_chains.is_empty():
				await _check_spring_turn(visual, _label(hero))
	var screen: Node = (load("res://scenes/ui/HeroSelect.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	var on_select: int = 0
	for node in screen.find_children("*", "CharacterVisual", true, false):
		var visual: CharacterVisual = node as CharacterVisual
		if visual.spring_chain_count() > 0:
			on_select += 1
			await _check_spring_turn(visual, "hero select")
	_check(on_select > 0, "hero select: a hero there has spring chains")
	screen.queue_free()
	await get_tree().process_frame
	await _check_mum_springs()


## Mum, as the story beats show her: her hair and pack swing on their
## chains, and her arrival walk, wave and cheer still play.
func _check_mum_springs() -> void:
	var mum: CharacterVisual = MumArrival.make_visual()
	add_child(mum)
	await get_tree().process_frame
	await _check_spring_turn(mum, "Mum")
	var player: AnimationPlayer = mum.model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check(player != null and player.has_animation(String(MumArrival.CLIPS[&"walk"])), "Mum: she can still walk in")
	_check(mum.play_action(&"wave") > 0.0 and await _wait_until(func() -> bool: return mum.playing_action() == &"wave", 1.0),
		"Mum: she still waves")
	_check(mum.play_action(&"cheer") > 0.0 and await _wait_until(func() -> bool: return mum.playing_action() == &"cheer", 1.0),
		"Mum: she still cheers")
	mum.queue_free()
	await get_tree().process_frame


func _check_spring_turn(visual: CharacterVisual, label: String) -> void:
	_check(visual.spring_chain_count() > 0, "%s: the visual swings its spring chains (%d)" % [label, visual.spring_chain_count()])
	visual.face_instantly(Vector3(0, 0, 1))
	_check(await _wait_until(func() -> bool: return visual.spring_swing() < SPRING_SETTLED, 3.0),
		"%s: standing, the chains rest (%.3f m)" % [label, visual.spring_swing()])
	# The peak over every simulation step, not the swing at a frame's end:
	# one long frame (the stalled pass) swings a chain out and most of the
	# way back before it ends.
	visual.clear_spring_peak()
	visual.face_instantly(Vector3(0, 0, -1))
	_check(await _wait_until(func() -> bool: return visual.spring_swing_peak() > SPRING_SWUNG, 0.5),
		"%s: a sudden turn swings a chain out (peak %.3f m)" % [label, visual.spring_swing_peak()])
	_check(await _wait_until(func() -> bool: return visual.spring_swing() < SPRING_SETTLED, SPRING_SETTLE_SECONDS),
		"%s: and it settles back within %.1f s (%.3f m)" % [label, SPRING_SETTLE_SECONDS, visual.spring_swing()])


## For Leo and Nela, played and as the companion: a hit freezes the
## attacker and the target but not the bystanders, and both resume. A
## target the hit kills still plays its death. An attack that strikes
## several mobs (Big Swing, Ricochet) freezes the hero once and each mob
## it strikes.
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
		# Last: the perk stays for the rest of the run.
		await _check_one_stop_per_attack(player)


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


## With the hero's strike-twice perk (Leo's Big Swing, Nela's Ricochet),
## one attack strikes two mobs: each mob is hit-stopped, the hero once.
func _check_one_stop_per_attack(who: Hero) -> void:
	var label: String = _label(who)
	var perk: StringName = &"ricochet" if who.hero.ranged else &"big_swing"
	PerkManager.take(who, perk)
	var first: Mob = await _stage_mob(who)
	# Ricochet bounces further than Big Swing reaches.
	var second: Mob = await _stage_mob(who, Vector3(1.5, 0, 2.5 if who.hero.ranged else 1.5))
	var visual: CharacterVisual = _visual_of(who)
	var targets: Array[CharacterVisual] = [_visual_of(first), _visual_of(second)]
	var stops: Array[int] = [visual.hit_stops, targets[0].hit_stops, targets[1].hit_stops]
	who.attack(first)
	var both_struck: Callable = func() -> bool:
		return first.current_hp < first.definition.max_hp and second.current_hp < second.definition.max_hp
	# Three tweens in a row (wind-up, flight, bounce): each takes a frame
	# at least, and a stalled frame is long.
	_check(await _wait_until(both_struck, 3.0), "%s, %s: one attack strikes two mobs" % [label, perk])
	_check(targets[0].hit_stops > stops[1] and targets[1].hit_stops > stops[2],
		"%s, %s: each mob struck is hit-stopped" % [label, perk])
	_check(visual.hit_stops - stops[0] == 1,
		"%s, %s: the hero is hit-stopped once for the attack (%d)" % [label, perk, visual.hit_stops - stops[0]])
	await _clear_staged_mobs()
	await _wait_until(func() -> bool: return _pebble_count() == 0, 2.0)


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


## The head look-at: for Leo and Nela, as the player's hero and as the
## companion, the head and chest turn toward the attack target while
## fighting and toward the resource while gathering, never past the cap.
## The heroes' AI and movement are held still (physics off), so only the
## look turns them.
func _run_look_at_scenario() -> void:
	print("smoke: --- hero animation: look-at ---")
	for party_hero in [&"leo", &"nela"]:
		await _start_fresh_run(_party(party_hero))
		for hero in Party.heroes():
			(hero as Node).set_physics_process(false)
		for hero in Party.heroes():
			await _check_fight_look(hero, _label(hero))
			await _check_gather_look(hero, _label(hero))


## A mob 90 degrees to the hero's side: the head turns that way, up to
## the cap; one LOOK_OFF_DEGREES off: the head turns about that far.
func _check_fight_look(hero: Hero, label: String) -> void:
	var visual: CharacterVisual = hero.get_node("Visual") as CharacterVisual
	var cap: float = CharacterLook.MAX_DEGREES
	var spot: Vector3 = _campfire().global_position + Vector3(8, 0, 6)
	hero.global_position = spot
	var mob: Mob = _spawn_mob(_beast(), spot + Vector3(1.6, 0, 0))
	mob.set_physics_process(false)
	await get_tree().process_frame
	_check(hero.attack(mob), "%s: attacks the staged mob" % label)
	# Facing +Z, the mob (at +X) is +90 degrees around the up axis.
	visual.face_instantly(Vector3(0, 0, 1))
	var turned: bool = await _wait_until(func() -> bool: return visual.look_turn_degrees() > cap - LOOK_NEAR_DEGREES,
		LOOK_SECONDS)
	_check(visual.look_focus() == mob and turned and visual.look_turn_degrees() <= cap + LOOK_SLACK_DEGREES,
		"%s: fighting, the head turns toward the mob to the side, capped (%.1f deg)" % [label, visual.look_turn_degrees()])
	# Facing round from +Z so the mob is LOOK_OFF_DEGREES off.
	var facing: float = deg_to_rad(90.0 - LOOK_OFF_DEGREES)
	visual.face_instantly(Vector3(sin(facing), 0, cos(facing)))
	var settled: bool = await _wait_until(
		func() -> bool: return absf(visual.look_turn_degrees() - LOOK_OFF_DEGREES) < LOOK_NEAR_DEGREES, LOOK_SECONDS)
	_check(settled, "%s: fighting, a mob %.0f deg off turns the head about that far (%.1f)"
		% [label, LOOK_OFF_DEGREES, visual.look_turn_degrees()])
	await _clear_staged_mobs()


## A resource node to the hero's other side while gathering: the head
## turns the other way, toward it.
func _check_gather_look(hero: Hero, label: String) -> void:
	var visual: CharacterVisual = hero.get_node("Visual") as CharacterVisual
	var cap: float = CharacterLook.MAX_DEGREES
	var node: ResourceNode = _find_resource_node(&"wood")
	hero.global_position = node.global_position + Vector3(-1.4, 0, 0)
	await get_tree().process_frame
	_check(hero.start_gather(node), "%s: starts gathering wood" % label)
	# Facing -Z, the tree (at +X) is -90 degrees around the up axis.
	visual.face_instantly(Vector3(0, 0, -1))
	var turned: bool = await _wait_until(func() -> bool: return visual.look_turn_degrees() < -(cap - LOOK_NEAR_DEGREES),
		LOOK_SECONDS)
	_check(visual.look_focus() == node and turned and visual.look_turn_degrees() >= -(cap + LOOK_SLACK_DEGREES),
		"%s: gathering, the head turns toward the tree, capped (%.1f deg)" % [label, visual.look_turn_degrees()])
	hero.cancel_gather()
