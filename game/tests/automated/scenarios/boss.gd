extends "res://tests/automated/smoke_scenario.gd"

## The Moon-Eater, Chapter 2's last night, from its eyes to the true
## ending.


func run() -> void:
	await _run_boss_scenario()


## The Moon-Eater. Its eyes watch on night 5; on night 7 it
## rises with a boss bar and holds the night; its stomp can be dodged;
## summons respect the mob cap and put out torches; scripted damage
## takes it through every phase, including a reach that runs out of
## time; calmed, it shrinks by the fire and the true ending plays.
func _run_boss_scenario() -> void:
	print("smoke: --- boss scenario ---")
	await _start_fresh_run(_run_of(RunConfig.for_chapter(2)))
	var spawner: MobSpawner = get_tree().get_first_node_in_group("mob_spawner") as MobSpawner
	_check(spawner.is_boss_night(7) and not spawner.is_boss_night(6), "the Moon-Eater comes on Chapter 2's last night")
	var wave: Array[MobDefinition] = spawner.build_wave(7)
	_check(wave[0].is_boss and wave.size() == 1 + spawner.boss_escort, "night 7 is the boss and %d imps" % spawner.boss_escort)

	# Night 5: its eyes at the treeline, gone at dawn.
	TimeManager.day_number = 5
	_skip_to_night()
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("moon_eater_eyes").size() == 1, "night 5: its eyes watch from the treeline")
	TimeManager.skip_phase()
	# Polled: the fade is a 1.5 s tween, and a fixed wait just past it can
	# end in a long frame before the tween's last step frees the eyes.
	_check(await _wait_until(func() -> bool: return get_tree().get_nodes_in_group("moon_eater_eyes").is_empty(), 3.0),
		"the eyes fade at dawn")

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
	var look: MoonEaterVisual = boss.get_node_or_null("Visual") as MoonEaterVisual if is_instance_valid(boss) else null
	_check(look != null and look.little_golem() != null and look.little_golem().curled,
		"it is the team's little golem, curled up")
	var pile: Node3D = get_tree().get_first_node_in_group(MoonEaterVisual.PILE_GROUP) as Node3D
	_check(pile != null and pile.get_child_count() >= 10 and pile.get_child(0).global_position.distance_to(fell_at) < 2.5,
		"it fell apart into a heap of planks and stones where it stood")
	_check(not hud.call("boss_bar_visible"), "the boss bar is gone")
	await get_tree().process_frame
	var mums: Array = get_tree().get_nodes_in_group("mum")  # the newest is this run's
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
	_check(book != null and book.page_count() == 3, "and the true ending opens (3 pages)")
	if book != null:
		book.next()
		book.next()
		book.next()
		await get_tree().process_frame
	StoryLibrary.forget_progress()
	# With the true ending forgotten again, only the win can open Endless.
	_check(GameManager.run_end.unlocked.has(&"endless") and (await _title_buttons()).has("endless"),
		"winning Chapter 2 unlocks Endless on the title")


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
