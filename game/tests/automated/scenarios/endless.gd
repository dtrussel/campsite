extends "res://tests/automated/smoke_scenario.gd"

## Endless runs, unlocked by the true ending, and their record.


func run() -> void:
	await _run_endless_scenario()
	await _run_endless_record_scenario()


## Once the true ending is seen, the title offers
## Endless: a Chapter 2 run with the Moon Lantern lit that keeps going
## past night 7 with no win and no Moon-Eater, and stays endless through
## save and Continue.
func _run_endless_scenario() -> void:
	print("smoke: --- endless scenario ---")
	await _close_main()
	StoryLibrary.forget_progress()
	_check(not (await _title_buttons()).has("endless"), "no Endless button before the true ending")
	StoryLibrary.mark_seen(StoryLibrary.TRUE_ENDING)
	_check((await _title_buttons()).has("endless"), "the true ending unlocks the Endless button")

	# An endless run: Chapter 2, the lantern lit, no Moon-Eater, no win.
	GameManager.set_party(&"leo")
	GameManager.nights_to_win = 7
	GameManager.endless = true  # as the title's Endless button sets it
	await _start_fresh_run()
	var spawner: MobSpawner = get_tree().get_first_node_in_group("mob_spawner") as MobSpawner
	var lantern: MoonLantern = MoonLantern.find(get_tree())
	_check(GameManager.endless and GameManager.chapter() == 2 and lantern.is_full(),
		"an endless run is Chapter 2 with the Moon Lantern lit (stage %d of %d)" % [lantern.stage, lantern.max_stage()])
	# The lit lantern takes no shards: E beside it keeps them for Glow
	# Lanterns and tool tiers.
	var shards_at_start: int = ResourceManager.get_count(MoonLantern.SHARD_ID)
	ResourceManager.add(MoonLantern.SHARD_ID, 6)
	var shards_before: int = ResourceManager.get_count(MoonLantern.SHARD_ID)
	var feeder: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	feeder.global_position = lantern.global_position + Vector3(1.0, 0, 0)
	var fed: bool = feeder.call("try_feed_lantern")
	var glow_lantern: BuildingDefinition = BuildManager.get_definition(&"glow_lantern")
	var sling: CraftingRecipe = load("res://resources/recipes/glow_sling.tres") as CraftingRecipe
	_check(not fed and not lantern.can_accept() and ResourceManager.get_count(MoonLantern.SHARD_ID) == shards_before
		and shards_before >= int(glow_lantern.cost.get(MoonLantern.SHARD_ID, 0))
		and shards_before >= int(sling.inputs.get(MoonLantern.SHARD_ID, 0)),
		"in endless the lit Moon Lantern takes no Glow Shards; they stay for Glow Lanterns and tiers (%d kept)"
		% ResourceManager.get_count(MoonLantern.SHARD_ID))
	ResourceManager.spend(MoonLantern.SHARD_ID, ResourceManager.get_count(MoonLantern.SHARD_ID) - shards_at_start)
	_check(not spawner.is_boss_night(7) and not spawner.build_wave(7).any(func(d: MobDefinition) -> bool: return d.is_boss),
		"no Moon-Eater in an endless night 7's wave")
	TimeManager.day_number = 5
	while not TimeManager.is_night():
		TimeManager.skip_phase()
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("moon_eater_eyes").is_empty(), "no eyes watch in endless")
	TimeManager.day_number = 7
	TimeManager.skip_phase()  # dawn 7
	_check(GameManager.is_playing(), "dawn 7 is no win in endless")
	_skip_to_night()  # night 8
	# Watch what the spawner sends: the Moon-Eater would come first.
	var spawned: Array = []
	spawner.mob_spawned.connect(func(_mob: Node3D, definition: MobDefinition) -> void: spawned.append(definition))
	await _wait(spawner.initial_delay_seconds + 1.0)
	_check(TimeManager.day_number == 8 and not spawned.is_empty() and not spawned.any(func(d: MobDefinition) -> bool: return d.is_boss),
		"night 8 comes, and no Moon-Eater rises (%d mobs so far)" % spawned.size())
	TimeManager.skip_phase()  # dawn 8
	await get_tree().process_frame
	_check(GameManager.is_playing() and int(GameManager.stats[&"nights_survived"]) == 8,
		"an endless run passes night 8 without a win")

	# Past night 7 mobs grow tougher and the heavies
	# and thieves take a growing share of the wave.
	var imp_hp: Array[int] = await _summoned_hp(spawner, [7, 9])
	_check(imp_hp[1] > imp_hp[0], "an imp on endless night 9 has more HP than on night 7 (%d > %d)" % [imp_hp[1], imp_hp[0]])
	var share_7: float = _heavy_sneak_share(spawner.build_wave(7), spawner)
	var share_10: float = _heavy_sneak_share(spawner.build_wave(10), spawner)
	_check(share_10 > share_7 + 0.1, "heavies and thieves make up more of endless night 10 than night 7 (%d%% > %d%%)"
		% [roundi(share_10 * 100.0), roundi(share_7 * 100.0)])

	# Dawn 8's autosave keeps the run endless through Continue.
	var data: Dictionary = SaveManager.load_save()
	_check(bool(data.get("endless", false)), "the autosave holds the endless flag")
	var caption: String = await _title_continue_caption()
	_check(caption.to_lower().ends_with("night 9"), "the title's Continue shows \"Night N\" in endless (%s)" % caption)
	GameManager.endless = false  # Continue takes it from the save
	await _continue_from(data)
	lantern = MoonLantern.find(get_tree())
	spawner = get_tree().get_first_node_in_group("mob_spawner") as MobSpawner
	_check(GameManager.endless and TimeManager.day_number == 9 and lantern.is_full() and not spawner.is_boss_night(7),
		"Continue keeps the run endless, at day 9 with the lantern lit")
	await _start_fresh_run()
	_check(GameManager.endless, "Again after an endless run is endless too")

	# A chapter run after it is a story run again.
	GameManager.endless = false  # as the title's chapter buttons set it
	await _start_fresh_run()
	_check(not GameManager.endless and not MoonLantern.find(get_tree()).is_full()
		and (get_tree().get_first_node_in_group("mob_spawner") as MobSpawner).is_boss_night(7),
		"a Chapter 2 run after endless has its dark lantern and its Moon-Eater")
	var story_spawner: MobSpawner = get_tree().get_first_node_in_group("mob_spawner") as MobSpawner
	var story_hp: Array[int] = await _summoned_hp(story_spawner, [7, 9])
	var story_10: Array[MobDefinition] = story_spawner.build_wave(10)
	_check(story_hp[1] == story_hp[0] and story_hp[0] == story_spawner.mob_definition.max_hp
		and story_10.count(story_spawner.heavy_definition) == 9 and story_10.count(story_spawner.sneak_definition) == 8
		and story_10.count(story_spawner.mob_definition) == 25,
		"a story run's mobs keep their HP and its night 10 keeps 25 imps, 9 beasts, 8 gremlins")
	GameManager.nights_to_win = 3
	StoryLibrary.forget_progress()


## An endless loss keeps the best nights and the hero
## in the profile (under "endless."), the end screen says "New record!"
## only when it is beaten, and the title's Endless button shows it.
func _run_endless_record_scenario() -> void:
	print("smoke: --- endless record scenario ---")
	await _close_main()
	Profile.forget("endless.")
	StoryLibrary.mark_seen(StoryLibrary.TRUE_ENDING)
	_check(not _endless_caption(await _title_buttons()).contains("Best:"), "no record on the Endless button before an endless run")

	# Leo lasts to night 9 and the fire goes out.
	GameManager.set_party(&"leo")
	GameManager.nights_to_win = 7
	GameManager.endless = true
	await _start_fresh_run()
	TimeManager.day_number = 8
	_skip_to_night()  # night 8
	TimeManager.skip_phase()  # dawn 8
	_skip_to_night()  # day 9, then night 9
	_check(GameManager.current_day == 9 and TimeManager.is_night(), "the endless run reaches night 9 (day %d)" % GameManager.current_day)
	_campfire().take_damage(10000)
	await get_tree().process_frame
	var end_screen: Node = _main.get_node("EndScreen")
	_check(GameManager.run_state == GameManager.RunState.LOST
		and int(Profile.get_value(Profile.ENDLESS_BEST_NIGHTS, 0)) == 9
		and String(Profile.get_value(Profile.ENDLESS_BEST_HERO, "")) == "leo",
		"a loss on night 9 records 9 nights and Leo")
	_check(String(end_screen.call("record_text")).contains("New record!"),
		"the end screen says New record! (%s)" % end_screen.call("record_text"))
	Profile.reload()  # as a restart reads it
	_check(int(Profile.get_value(Profile.ENDLESS_BEST_NIGHTS, 0)) == 9 and String(Profile.get_value(Profile.ENDLESS_BEST_HERO, "")) == "leo",
		"the record survives a restart")
	var caption: String = _endless_caption(await _title_buttons())
	_check(caption.contains("night 9") and caption.contains("Leo"), "the Endless button shows the record (%s)" % caption)

	# A worse run, with Nela on night 1, keeps Leo's record.
	GameManager.set_party(&"nela")
	await _start_fresh_run()
	_campfire().take_damage(10000)
	await get_tree().process_frame
	end_screen = _main.get_node("EndScreen")
	_check(int(Profile.get_value(Profile.ENDLESS_BEST_NIGHTS, 0)) == 9 and String(Profile.get_value(Profile.ENDLESS_BEST_HERO, "")) == "leo",
		"a worse run doesn't overwrite the record")
	_check(not String(end_screen.call("record_text")).contains("New record!") and String(end_screen.call("record_text")).contains("night 9"),
		"no New record! for a worse run; it shows the best (%s)" % end_screen.call("record_text"))

	# A story run's loss is no endless record.
	GameManager.endless = false
	await _start_fresh_run()
	_campfire().take_damage(10000)
	await get_tree().process_frame
	_check(String(_main.get_node("EndScreen").call("record_text")) == "", "a story run's end screen has no record line")
	await _close_main()
	GameManager.set_party(&"leo")
	GameManager.nights_to_win = 3
	Profile.forget("endless.")
	StoryLibrary.forget_progress()


## The record line under the title's Endless button, from
## _title_buttons (the button's tooltip carries it).
func _endless_caption(buttons: Dictionary) -> String:
	return str(buttons.get("endless", ""))


## Summons one imp on each of `nights` (the clock's day set to it) and
## returns their HP, freeing them again.
func _summoned_hp(spawner: MobSpawner, nights: Array) -> Array[int]:
	var day: int = TimeManager.day_number
	var hp: Array[int] = []
	var got: Array[Mob] = []
	var grab: Callable = func(mob: Node3D, _definition: MobDefinition) -> void: got.append(mob as Mob)
	spawner.mob_spawned.connect(grab)
	for night in nights:
		TimeManager.day_number = int(night)
		spawner.summon(spawner.mob_definition, 1)
		hp.append(got.back().current_hp if not got.is_empty() and got.back() != null else -1)
	spawner.mob_spawned.disconnect(grab)
	TimeManager.day_number = day
	for mob in got:
		if mob != null:
			mob.queue_free()
	await get_tree().process_frame
	return hp


## The share of a wave that is beasts or gremlins (not imps).
func _heavy_sneak_share(wave: Array[MobDefinition], spawner: MobSpawner) -> float:
	var others: int = wave.size() - wave.count(spawner.mob_definition)
	return float(others) / float(maxi(1, wave.size()))


## Opens the title screen and returns its captioned buttons, as
## {lower-case caption: tooltip}. The screen is gone again by the time
## this returns.
func _title_buttons() -> Dictionary:
	var game_camera: Camera3D = get_viewport().get_camera_3d()
	var title: Control = (load("res://scenes/ui/TitleScreen.tscn") as PackedScene).instantiate()
	add_child(title)
	await get_tree().process_frame
	var found: Dictionary = {}
	for node in title.find_children("*", "Button", true, false):
		var caption: String = (node as Button).text.strip_edges().to_lower()
		if caption != "":
			found[caption] = (node as Button).tooltip_text
	title.free()
	if game_camera != null and is_instance_valid(game_camera):
		game_camera.make_current()
	return found


## The visible caption under the title screen's Continue button, or "".
func _title_continue_caption() -> String:
	var game_camera: Camera3D = get_viewport().get_camera_3d()
	var title: TitleScreen = (load("res://scenes/ui/TitleScreen.tscn") as PackedScene).instantiate() as TitleScreen
	add_child(title)
	await get_tree().process_frame
	var caption: Label = title.continue_caption()
	var text: String = caption.text if caption != null and caption.is_visible_in_tree() else ""
	title.free()
	if game_camera != null and is_instance_valid(game_camera):
		game_camera.make_current()
	return text
