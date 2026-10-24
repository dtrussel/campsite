extends "res://tests/automated/smoke_scenario.gd"

## A whole Chapter 1 played for real: Chapter 2 locked on the title, a
## won run through the core systems, the chapter lock the win opens, a
## lost run, and Continue from the win's night-1 autosave. One script,
## because each step needs the one before it.


## The autosave written after night 1 of the win, for Continue.
var _night1_save: Dictionary = {}


func run() -> void:
	await _check_title_chapter_2(false, "the title locks Chapter 2 before Chapter 1 is won")
	await _run_win_scenario()
	await _run_chapter_lock_scenario()
	await _run_loss_scenario()
	await _run_continue_scenario()


## Opens the title screen and checks whether its Chapter 2 button can be
## pressed.
func _check_title_chapter_2(unlocked: bool, label: String) -> void:
	var title: Node = (load("res://scenes/ui/TitleScreen.tscn") as PackedScene).instantiate()
	add_child(title)
	await get_tree().process_frame
	var button: Button = title.call("chapter_button", 2) as Button
	_check(button != null and button.disabled != unlocked and Profile.is_chapter_unlocked(2) == unlocked, label)
	title.queue_free()
	await get_tree().process_frame


func _run_win_scenario() -> void:
	print("smoke: --- win scenario ---")
	await _start_fresh_run()
	_check(GameManager.is_playing(), "run is PLAYING after scene load")
	_check(TimeManager.is_running, "clock is running")
	_check(ResourceManager.get_definitions().size() == 9, "items loaded: 6 raw + 3 crafted (%d)" % ResourceManager.get_definitions().size())
	_check(BuildManager.get_known_definitions().size() == 7, "7 buildings loaded")
	_check(CraftingManager.get_recipes().size() >= 1, "recipes loaded")

	var player: Node3D = get_tree().get_first_node_in_group("player")
	var companion: Node3D = get_tree().get_first_node_in_group("companions")
	_check(player != null and companion != null, "player and companion exist")

	# Audio: the day tune plays, and one-shots from the pool never error.
	var library: AudioLibrary = AudioManager.library
	_check(library != null and library.music_day != null, "audio library loaded")
	_check(AudioManager.mood == &"day", "day music mood at run start (%s)" % AudioManager.mood)
	for id in library.volumes.keys():
		AudioManager.play_sfx(StringName(id), player.global_position)
	AudioManager.play_sfx(&"no_such_sound")  # unknown ids are ignored

	# Gather from a tree: wood, with no leaves bonus.
	var tree_node: ResourceNode = _find_resource_node(&"wood")
	_check(tree_node != null, "found a tree")
	_check(tree_node.begin_gather(player), "gather started")
	await _wait(tree_node.gather_time_seconds + 0.3)
	_check(ResourceManager.get_count(&"wood") >= 2, "gathered wood")
	_check(ResourceManager.get_definition(&"leaves") == null and ResourceManager.get_definition(&"fiber") == null,
		"playtest 1: leaves, fiber, resin and mushrooms are gone")
	_check(ProgressionManager.get_xp(player) > 0, "gather awarded XP")


	# Craft and plant a torch.
	var torch_recipe: CraftingRecipe = _recipe(&"torch")
	_check(CraftingManager.craft(torch_recipe, player), "crafted a torch")
	_check(ResourceManager.get_count(&"torch") == 1, "torch in inventory")
	player.call("try_place_torch")
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("torches").size() == 1, "torch planted")
	_check(ResourceManager.get_count(&"torch") == 0, "torch consumed")

	# A fence instance loads and takes damage.
	var fence_def: BuildingDefinition = BuildManager.get_definition(&"wooden_fence")
	var fence: Building = fence_def.get_scene().instantiate() as Building
	get_tree().current_scene.add_child(fence)
	fence.global_position = Vector3(0, 0, -4)
	fence.take_damage(5)
	_check(fence.current_hp == fence_def.max_hp - 5, "fence takes damage")

	await _check_repair_and_traps(player, companion, fence)

	# LoL-style commands: navmesh, move, gather, attack.
	var nav: NavigationRegion3D = get_tree().current_scene.find_child("Navigation", true, false) as NavigationRegion3D
	var waited_nav: float = 0.0
	while (nav == null or nav.navigation_mesh == null or nav.navigation_mesh.get_polygon_count() == 0) and waited_nav < 8.0:
		await _wait(0.25)
		waited_nav += 0.25
	_check(nav != null and nav.navigation_mesh.get_polygon_count() > 0, "navmesh baked (%d polys)" % (nav.navigation_mesh.get_polygon_count() if nav != null else 0))
	var goal: Vector3 = Vector3(-6, 0, 10)
	player.command_move(goal)
	var t: float = 0.0
	while bool(player.call("has_command")) and t < 10.0:
		await _wait(0.25)
		t += 0.25
	var moved: float = Vector2(player.global_position.x - goal.x, player.global_position.z - goal.z).length()
	_check(moved < 1.0, "right-click move arrived (%.2f m off, %.1fs)" % [moved, t])

	await _check_animation_layers(player)

	var rock: ResourceNode = _find_resource_node(&"stone")
	var stone_before: int = ResourceManager.get_count(&"stone")
	player.command_gather(rock)
	t = 0.0
	while ResourceManager.get_count(&"stone") == stone_before and t < 15.0:
		await _wait(0.25)
		t += 0.25
	_check(ResourceManager.get_count(&"stone") > stone_before, "gather command walked over and gathered (%.1fs)" % t)

	var target_imp: Mob = (load("res://scenes/mobs/ShadowImp.tscn") as PackedScene).instantiate() as Mob
	get_tree().current_scene.add_child(target_imp)
	target_imp.global_position = player.global_position + Vector3(3.5, 0, 0)
	var kills_before_cmd: int = int(GameManager.stats[&"kills"])
	player.command_attack(target_imp)
	t = 0.0
	while is_instance_valid(target_imp) and target_imp.current_hp > 0 and t < 15.0:
		await _wait(0.25)
		t += 0.25
	_check(int(GameManager.stats[&"kills"]) > kills_before_cmd, "attack command chased and auto-attacked an imp to death (%.1fs)" % t)
	player.stop_commands()

	await _check_auto_attack(player)
	await _check_companion_unstuck(companion)
	await _check_construction(player, companion)

	# Watch Post pelts a nearby imp on its own.
	var post_def: BuildingDefinition = BuildManager.get_definition(&"watch_post")
	var post: Building = post_def.get_scene().instantiate() as Building
	get_tree().current_scene.add_child(post)
	post.global_position = Vector3(12, 0, 12)
	var imp: Mob = (load("res://scenes/mobs/ShadowImp.tscn") as PackedScene).instantiate() as Mob
	get_tree().current_scene.add_child(imp)
	imp.global_position = Vector3(14, 0, 12)
	imp.set_physics_process(false)  # hold still for the check
	var imp_hp: int = imp.current_hp
	await _wait(post.auto_attack_interval + 0.5)
	_check(imp.current_hp < imp_hp, "watch post damaged a nearby imp (%d -> %d)" % [imp_hp, imp.current_hp])
	imp.take_damage(999, player)

	companion.call("set_task", Companion.Task.GUARD_BASE)
	for night in range(1, RunSession.config.nights_to_win + 1):
		await _survive_night(night, player)
		if night == 1:
			await get_tree().process_frame  # the autosave runs deferred
			_night1_save = SaveManager.load_save()
			_check(not _night1_save.is_empty() and int(_night1_save["day"]) == 1, "autosaved at dawn after night 1")
			_check(int(_night1_save.get("inventory", {}).get("wood", 0)) == ResourceManager.get_count(&"wood"),
				"autosave has the inventory (wood %d)" % ResourceManager.get_count(&"wood"))
			var card: StoryCard = _main.get_node("HUD").call("story_card")
			_check(card != null and card.lines().size() == 2 and String(card.lines()[0]["speaker"]) == "leo"
				and String(card.lines()[0]["id"]).begins_with("dawn.c1.n1"), "dawn 1: Leo and Nela talk on the dawn card")
		if night < RunSession.config.nights_to_win:
			_check(GameManager.is_playing(), "still playing after night %d" % night)
	_check(GameManager.run_state == GameManager.RunState.WON, "run WON after %d nights" % RunSession.config.nights_to_win)
	# The Chapter 1 ending book comes before the stats.
	var end_root: Control = _main.get_node("EndScreen").get("_root")
	await get_tree().process_frame  # the book opens deferred
	var book: StoryBook = get_tree().get_first_node_in_group("story_book") as StoryBook
	_check(book != null and book.page_count() == 2 and not end_root.visible, "the Chapter 1 ending opens before the stats")
	if book != null:
		book.next()
		_check(book.page == 1, "the ending turns its page")
		book.next()
		await get_tree().process_frame
	_check(end_root.visible, "the stats show after the ending")
	_check(int(GameManager.stats[&"kills"]) > 0, "kills recorded (%d)" % GameManager.stats[&"kills"])
	_check(get_tree().paused, "world frozen behind end screen")
	_check(AudioManager.mood == &"", "music stops for the win stinger")
	_check(not SaveManager.has_save(), "a won run deletes its save")
	var shards_seen: int = ResourceManager.get_count(&"glow_shards") + get_tree().get_nodes_in_group("pickups").size()
	_check(shards_seen >= int(GameManager.stats[&"kills"]) / 3 - 1, "imps dropped glow shards (%d for %d kills)" % [shards_seen, GameManager.stats[&"kills"]])


## Winning Chapter 1 unlocks Chapter 2 on the title,
## and it stays unlocked after a restart (the profile read again from
## its file). A profile whose story.cfg import found Chapter 2 played
## opens with it unlocked. Hero select opens on the last hero picked,
## after a restart too. Delete profile asks first, then relocks Chapter
## 2 and leaves audio and graphics settings alone.
func _run_chapter_lock_scenario() -> void:
	print("smoke: --- chapter lock scenario ---")
	await _close_main()
	await _check_title_chapter_2(true, "the title unlocks Chapter 2 once Chapter 1 is won")
	Profile.reload()
	await _check_title_chapter_2(true, "Chapter 2 stays unlocked after a restart")

	# The last hero picked, kept in the profile.
	var screen: Node = (load("res://scenes/ui/HeroSelect.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	screen.call("select", 1)
	GameManager.record_hero_pick((screen.call("selected_hero") as HeroDefinition).id)
	screen.queue_free()
	RunSession.forget_last_run()  # what a fresh start would hold: Leo
	Profile.reload()
	screen = (load("res://scenes/ui/HeroSelect.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	_check((screen.call("selected_hero") as HeroDefinition).id == &"nela",
		"hero select opens on the last hero picked (Nela), after a restart too")
	screen.queue_free()
	await get_tree().process_frame

	# Delete profile, from the settings in the pause menu: it asks first.
	var music: float = AudioManager.music_volume
	var blur: int = PostFx.blur_level()
	var strong_blur: int = PostFx.Blur.STRONG if blur != PostFx.Blur.STRONG else PostFx.Blur.OFF
	PostFx.set_blur_level(strong_blur)
	var menu: Node = (load("res://scenes/ui/PauseMenu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	(menu.get("delete_profile_button") as Button).pressed.emit()
	var confirm: ConfirmationDialog = menu.get("delete_profile_confirm") as ConfirmationDialog
	_check(confirm != null and confirm.visible and Profile.is_chapter_unlocked(2),
		"Delete profile asks first and deletes nothing yet")
	var warning: String = confirm.dialog_text.to_lower() if confirm != null else ""
	_check(warning.contains("all") and warning.contains("progress") and warning.contains("badges")
		and warning.contains("journal"), "the confirmation says plainly it erases all progress (%s)" % warning)
	confirm.canceled.emit()
	_check(Profile.is_chapter_unlocked(2), "cancelling keeps the profile")
	(menu.get("delete_profile_button") as Button).pressed.emit()
	confirm.confirmed.emit()
	menu.queue_free()
	await _check_title_chapter_2(false, "Delete profile relocks Chapter 2")
	_check(is_equal_approx(AudioManager.music_volume, music), "Delete profile leaves the audio settings alone")
	_check(PostFx.blur_level() == strong_blur, "Delete profile leaves the graphics settings alone")
	PostFx.set_blur_level(blur)
	_check(not Profile.has_value(Profile.LAST_HERO), "Delete profile forgets the last hero")

	# A player the story.cfg import marked as having played Chapter 2.
	var old_story: String = "user://smoke_old_story.cfg"
	var old: ConfigFile = ConfigFile.new()
	old.set_value("seen", "intro.c2", true)
	old.save(old_story)
	var imported_path: String = "user://smoke_imported_profile.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(imported_path))
	Profile.set_path(imported_path, old_story)
	await _check_title_chapter_2(true, "an imported Chapter 2 player sees Chapter 2 unlocked on first launch")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(old_story))
	Profile.delete()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(imported_path))
	Profile.set_path(TEST_PROFILE_PATH)
	Profile.delete()


func _run_loss_scenario() -> void:
	print("smoke: --- loss scenario ---")
	await _start_fresh_run()
	_check(GameManager.is_playing(), "second run is PLAYING")
	_check(ResourceManager.get_count(&"wood") == 0, "inventory reset between runs")
	var player: Node = get_tree().get_first_node_in_group("player")
	_check(ProgressionManager.get_level(player) == 1 and ProgressionManager.get_xp(player) == 0, "progression reset")
	_campfire().take_damage(10000)
	await get_tree().process_frame
	_check(GameManager.run_state == GameManager.RunState.LOST, "run LOST when campfire destroyed")
	var end_screen: Node = _main.get_node("EndScreen")
	_check(String(end_screen.call("story_text")).begins_with("The dark came in") and (end_screen.get("_root") as Control).visible,
		"the defeat says why: %s" % end_screen.call("story_text"))
	_check(not SaveManager.has_save(), "no save after a lost run")

	# Volume settings round-trip through user://settings.cfg.
	var saved_music: float = AudioManager.music_volume
	AudioManager.set_music_volume(0.35)
	var config: ConfigFile = ConfigFile.new()
	_check(config.load(AudioManager.SETTINGS_PATH) == OK and is_equal_approx(float(config.get_value("audio", "music")), 0.35),
		"music volume saved to settings.cfg")
	AudioManager.set_music_volume(saved_music)


## Continue rebuilds the camp from the night-1 autosave,
## and a 7-night run shows 7 moons and bigger waves.
func _run_continue_scenario() -> void:
	print("smoke: --- continue scenario ---")
	# Buildings from earlier checks live on the test root; clear them so
	# only the restored ones remain.
	for node in get_tree().get_nodes_in_group(Building.BUILDINGS_GROUP):
		node.queue_free()
	await get_tree().process_frame
	var data: Dictionary = _night1_save
	_check(not data.is_empty(), "have the night-1 save to continue")
	if data.is_empty():
		return
	# Damaged or foreign saves are refused.
	_check(SaveManager.parse("{not json").is_empty(), "a corrupt save is ignored")
	var old_version: Dictionary = data.duplicate(true)
	var text: String = SaveManager.serialize(old_version).replace('"version": %d' % SaveManager.VERSION, '"version": 99')
	_check(SaveManager.parse(text).is_empty(), "a save from another version is ignored")
	_check(SaveManager.parse(SaveManager.serialize(data)).hash() == SaveManager.parse(SaveManager.serialize(data)).hash()
		and not SaveManager.parse(SaveManager.serialize(data)).is_empty(), "save round-trips through JSON")

	await _continue_from(data, _run_of(RunConfig.for_chapter(2)))  # the run length comes from the save
	_check(RunSession.config.nights_to_win == int(data["nights_to_win"]) and RunSession.config.chapter == 1,
		"continued at the saved run length and chapter (%d nights, Chapter %d)" % [RunSession.config.nights_to_win, RunSession.config.chapter])
	_check(TimeManager.day_number == 2 and TimeManager.current_phase == TimeManager.Phase.DAY, "continued at the morning of day 2")
	_check(ResourceManager.get_count(&"wood") == int(data["inventory"].get("wood", 0)), "inventory restored")
	var buildings: int = get_tree().get_nodes_in_group(Building.BUILDINGS_GROUP).size()
	_check(buildings == (data["buildings"] as Array).size(), "buildings restored (%d)" % buildings)
	var fire: BaseCore = _campfire()
	_check(fire.has_hearth == bool(data["campfire"]["hearth"]) and fire.current_hp == int(data["campfire"]["hp"]),
		"campfire restored (%d HP, hearth %s)" % [fire.current_hp, fire.has_hearth])
	var player: Node = get_tree().get_first_node_in_group("player")
	_check(ProgressionManager.get_xp(player) == int(data["player"]["xp"]) and int(player.get("tool_tier")) == int(data["player"]["tier"]),
		"Leo's progress restored (level %d)" % ProgressionManager.get_level(player))
	_check(int(GameManager.stats[&"nights_survived"]) == 1, "stats restored (1 night survived)")

	# A 7-night run.
	await _start_fresh_run(_run_of(RunConfig.for_chapter(2)))
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud == null:
		hud = _main.get_node_or_null("HUD")
	_check(hud != null and (hud.get("_moons") as Array).size() == 7, "7-night run shows 7 moons")
	var spawner: Node = get_tree().get_first_node_in_group("mob_spawner")
	_check(spawner.get_wave_size(7) == 19 and spawner.get_heavy_count(7) == 6, "night 7: 19 imps and 6 beasts")


## Repair, the clay and scrap nodes, recipes, traps and lanterns.
func _check_repair_and_traps(player: Node3D, companion: Node3D, fence: Building) -> void:
	# New resource nodes all gather.
	for item in [&"clay", &"scrap"]:
		var node: ResourceNode = _find_resource_node(item)
		_check(node != null and node.begin_gather(player), "gather started on %s" % item)
		if node != null:
			await _wait(node.gather_time_seconds + 0.3)
		_check(ResourceManager.get_count(item) >= 1, "gathered %s" % item)

	# Repair: one tap spends a wood and fixes the fence.
	ResourceManager.add(&"wood", 5)
	var wood_before: int = ResourceManager.get_count(&"wood")
	var hp_before: int = fence.current_hp
	_check(Repair.needs_repair(fence), "damaged fence needs repair")
	_check(Repair.tap(fence, player), "repair tap succeeded")
	_check(fence.current_hp > hp_before and ResourceManager.get_count(&"wood") == wood_before - 1,
		"repair restored HP (%d -> %d) for 1 wood" % [hp_before, fence.current_hp])
	_check(not Repair.needs_repair(fence), "fence fully repaired")

	# Leo's repair command walks over and hammers.
	fence.take_damage(20)
	player.command_repair(fence)
	var t: float = 0.0
	while Repair.needs_repair(fence) and t < 10.0:
		await _wait(0.25)
		t += 0.25
	_check(not Repair.needs_repair(fence), "repair command fixed the fence (%.1fs)" % t)

	# Nela's Repair task fixes the campfire.
	var fire: BaseCore = _campfire()
	fire.take_damage(30)
	companion.call("set_task", Companion.Task.REPAIR)
	t = 0.0
	while fire.get_missing_hp() > 0 and t < 15.0:
		await _wait(0.25)
		t += 0.25
	_check(fire.get_missing_hp() == 0, "Nela repaired the campfire (%.1fs)" % t)
	companion.call("set_task", Companion.Task.IDLE)

	# Feed the Fire only while the campfire is damaged.
	var feed: CraftingRecipe = _recipe(&"feed_fire")
	_check(feed != null and not CraftingManager.can_craft(feed), "feed the fire disabled at full HP")
	fire.take_damage(25)
	ResourceManager.add(&"wood", 1)
	var fire_hp: int = fire.current_hp
	_check(CraftingManager.craft(feed, player) and fire.current_hp == fire_hp + fire.repair_per_tap, "fed the fire (+%d)" % fire.repair_per_tap)

	# Stone Hearth: once per run, more max HP.
	ResourceManager.add(&"clay", 5)
	ResourceManager.add(&"stone", 4)
	var hearth: CraftingRecipe = _recipe(&"stone_hearth")
	var max_before: int = fire.max_hp
	_check(CraftingManager.craft(hearth, player), "built the stone hearth")
	_check(fire.has_hearth and fire.max_hp == max_before + fire.hearth_bonus_hp and fire.current_hp == fire.max_hp,
		"hearth raised campfire max HP to %d and healed it" % fire.max_hp)
	ResourceManager.add(&"clay", 5)
	ResourceManager.add(&"stone", 4)
	_check(not CraftingManager.can_craft(hearth), "hearth only once per run")

	# Berry Snack: crafted, then eaten first with R.
	ResourceManager.add(&"berries", 3)
	_check(CraftingManager.craft(_recipe(&"berry_snack"), player) and ResourceManager.get_count(&"snack") == 1, "cooked a berry snack")
	(player as Hero).clear_invulnerability()
	player.take_damage(40)
	var hp: int = player.current_hp
	player.call("try_eat_berries")
	# A level-up earlier in the run may have dealt Berry Belly.
	var snack_heal: int = roundi(player.heal_per_snack * PerkManager.multiplier(player, &"snack_heal"))
	_check(player.current_hp == mini(player.max_hp, hp + snack_heal) and ResourceManager.get_count(&"snack") == 0,
		"ate the snack (+%d HP)" % snack_heal)

	# Snap trap: holds and hurts the first imp, uses a charge.
	var trap: SnapTrap = (load("res://scenes/buildings/SnapTrap.tscn") as PackedScene).instantiate() as SnapTrap
	get_tree().current_scene.add_child(trap)
	trap.global_position = Vector3(-14, 0, -4)
	var trapped: Mob = (load("res://scenes/mobs/ShadowImp.tscn") as PackedScene).instantiate() as Mob
	get_tree().current_scene.add_child(trapped)
	trapped.global_position = Vector3(-14, 0, -4.2)
	var trapped_hp: int = trapped.current_hp
	t = 0.0
	while trap.current_hp == 3 and t < 5.0:
		await _wait(0.1)
		t += 0.1
	_check(trap.current_hp == 2 and trapped.current_hp < trapped_hp and trapped.is_stunned(),
		"snap trap caught an imp (hp %d -> %d, charges left %d)" % [trapped_hp, trapped.current_hp, trap.current_hp])
	trapped.take_damage(999, player)

	# Glow Lantern: a permanent aura that slows and zaps imps.
	var lantern: Building = (load("res://scenes/buildings/GlowLantern.tscn") as PackedScene).instantiate() as Building
	get_tree().current_scene.add_child(lantern)
	lantern.global_position = Vector3(14, 0, -4)
	var zapped: Mob = (load("res://scenes/mobs/ShadowImp.tscn") as PackedScene).instantiate() as Mob
	get_tree().current_scene.add_child(zapped)
	zapped.global_position = Vector3(12, 0, -4)
	zapped.set_physics_process(false)
	var zapped_hp: int = zapped.current_hp
	await _wait(2.3)
	_check(zapped.call("_torch_slow_factor") < 1.0, "lantern aura slows imps")
	_check(zapped.current_hp < zapped_hp, "lantern aura zaps imps (%d -> %d)" % [zapped_hp, zapped.current_hp])
	zapped.take_damage(999, player)
	var aura: Node = lantern.get_node("Aura")
	_check(not TimeManager.dawn_started.is_connected(aura.get("_on_dawn_started")), "lantern aura does not burn out at dawn")
	lantern.queue_free()

	await _check_bramble_beast(player)
	await _check_storage_and_table(player, companion)
	await _check_mushroom_gremlin(player)


## Stash caps, the Storage Crate, the Reinforced Wall and
## the Crafting Table recipes.
func _check_storage_and_table(player: Node3D, companion: Node3D) -> void:
	# Caps: 20 wood, 40 with a crate; losing the crate keeps what you have.
	ResourceManager.add(&"wood", 100)
	_check(ResourceManager.get_count(&"wood") == 20 and ResourceManager.is_full(&"wood"), "wood caps at 20")
	var crate: Building = _spawn_building(&"storage_crate", Vector3(-6, 0, -12))
	await get_tree().process_frame
	_check(ResourceManager.get_cap(&"wood") == 40, "a storage crate raises the cap to 40")
	ResourceManager.add(&"wood", 100)
	_check(ResourceManager.get_count(&"wood") == 40, "wood fills to 40")
	crate.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(ResourceManager.get_cap(&"wood") == 20 and ResourceManager.get_count(&"wood") == 40,
		"losing the crate lowers the cap but keeps the wood")
	ResourceManager.spend(&"wood", 25)

	# The Reinforced Wall is 3x a fence; a beast still does 12 a hit.
	var wall: Building = _spawn_building(&"reinforced_wall", Vector3(-8, 0, 14))
	_check(wall.current_hp == 150 and wall.is_in_group(Repair.GROUP), "reinforced wall has 150 HP and is repairable")
	var beast_def: MobDefinition = get_tree().get_first_node_in_group("mob_spawner").get("heavy_definition")
	var beast: Mob = beast_def.get_scene().instantiate() as Mob
	get_tree().current_scene.add_child(beast)
	beast.global_position = Vector3(-8, 0, 16.5)
	var t: float = 0.0
	while wall.current_hp == 150 and t < 15.0:
		await _wait(0.25)
		t += 0.25
	_check(wall.current_hp == 138, "beast hits the wall for 12 (%d left)" % wall.current_hp)
	beast.take_damage(999, player)
	wall.queue_free()

	# Crafting Table recipes are locked until a table stands in the camp.
	for item in [&"wood", &"scrap", &"berries"]:
		ResourceManager.add(item, 10)
	var stick: CraftingRecipe = _recipe(&"sturdy_stick")
	_check(stick.station == CraftingRecipe.STATION_TABLE and not CraftingManager.can_craft(stick), "table recipes locked without a table")
	var table: Building = _spawn_building(&"crafting_table", Vector3(5, 0, -6))
	_check(CraftingManager.has_table() and CraftingManager.can_craft(stick), "a crafting table unlocks them")
	var damage: int = int(player.get("attack_damage"))
	_check(CraftingManager.craft(stick, player) and int(player.get("attack_damage")) == damage + 2, "sturdy stick: +2 attack")
	_check(not CraftingManager.can_craft(stick), "sturdy stick only once")
	var reach: float = companion.call("get_attack_range")
	_check(CraftingManager.craft(_recipe(&"slingshot"), player) and is_equal_approx(companion.call("get_attack_range"), reach * 2.0),
		"slingshot doubles Nela's reach")

	# Bandage wakes a knocked-out Nela (X next to her).
	_check(CraftingManager.craft(_recipe(&"bandage"), player) and ResourceManager.get_count(&"bandage") == 1, "made a bandage")
	(companion as Hero).clear_invulnerability()
	companion.take_damage(999)
	_check((companion as Hero).is_down(), "Nela knocked out")
	companion.global_position = player.global_position + Vector3(1.0, 0, 0)
	_check(player.call("try_use_bandage") and not (companion as Hero).is_down() and ResourceManager.get_count(&"bandage") == 0,
		"bandage woke Nela up (%d HP)" % companion.get("current_hp"))

	# Trap Refill restores a used trap.
	var refill: CraftingRecipe = _recipe(&"trap_refill")
	var trap: SnapTrap = _spawn_building(&"snap_trap", Vector3(-14, 0, 8)) as SnapTrap
	for other in get_tree().get_nodes_in_group(SnapTrap.GROUP):
		(other as SnapTrap).recharge()  # the trap above has used a snap
	_check(not CraftingManager.can_craft(refill), "trap refill needs a used trap")
	trap.current_hp = 1
	_check(CraftingManager.craft(refill, player) and trap.current_hp == 3, "trap refill restored all snaps")
	trap.queue_free()
	table.queue_free()
	await get_tree().process_frame


## Mushroom Gremlins steal from the stash and run; caught,
## they drop the loot; escaped, it is gone.
func _check_mushroom_gremlin(player: Node3D) -> void:
	var spawner: Node = get_tree().get_first_node_in_group("mob_spawner")
	var gremlin_def: MobDefinition = spawner.get("sneak_definition")
	_check(gremlin_def != null and gremlin_def.steals_resources, "spawner has a thief (mushroom gremlin)")
	var wave: Array = spawner.build_wave(2)
	var first: int = wave.find(gremlin_def)
	_check(first >= 0 and first < wave.size() / 2, "night 2: the gremlin sneaks in early")

	# It steals the most plentiful resource from the campfire stash...
	for item in [&"wood", &"stone", &"berries", &"clay", &"scrap", &"glow_shards"]:
		ResourceManager.spend(item, ResourceManager.get_count(item))
	ResourceManager.add(&"stone", 10)
	ResourceManager.add(&"wood", 3)
	player.global_position = Vector3(-12, 0, -8)  # out of the way
	var thief: Mob = _spawn_mob(gremlin_def, Vector3(0, 0, 12))
	var t: float = 0.0
	while int(thief.get("loot_amount")) == 0 and t < 15.0:
		await _wait(0.25)
		t += 0.25
	_check(thief.loot_id == &"stone" and thief.loot_amount == 4 and ResourceManager.get_count(&"stone") == 6,
		"gremlin stole 4 stone (%.1fs)" % t)
	_check(thief.is_fleeing and ResourceManager.get_count(&"wood") == 3, "it runs off and leaves the wood")
	# Its own clips; it sneaks in and scurries off.
	var visual: CharacterVisual = thief.get_node("Visual") as CharacterVisual
	var anim_player: AnimationPlayer = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var missing: Array = []
	for state in visual.clips.keys():
		if not anim_player.has_animation(String(visual.clips[state])):
			missing.append(visual.clips[state])
	_check(missing.is_empty(), "gremlin model has all its clips %s" % [missing])
	_check(visual.current_move_clip() == StringName(visual.clips[&"flee"]),
		"a fleeing gremlin scurries (%s)" % visual.current_move_clip())
	# ...and drops it when caught.
	var at: Vector3 = thief.global_position
	thief.take_damage(999, player)
	await get_tree().process_frame
	var loot: Node3D = null
	for pickup in get_tree().get_nodes_in_group("pickups"):
		if pickup.get("item_id") == &"stone" and (pickup as Node3D).global_position.distance_to(Vector3(at.x, 0, at.z)) < 1.0:
			loot = pickup
	_check(loot != null and int(loot.get("amount")) == 4, "caught gremlin dropped its loot")
	if loot != null:
		player.global_position = loot.global_position
		await _wait(0.3)
		_check(ResourceManager.get_count(&"stone") == 10, "walking over the loot got it back")

	# An escaped gremlin keeps what it took.
	var lost_before: int = int(GameManager.stats.get(&"stolen_lost", 0))
	player.global_position = Vector3(-12, 0, -8)
	var runner: Mob = _spawn_mob(gremlin_def, Vector3(0, 0, 12))
	t = 0.0
	while is_instance_valid(runner) and t < 20.0:
		await _wait(0.25)
		t += 0.25
	_check(not is_instance_valid(runner) and int(GameManager.stats.get(&"stolen_lost", 0)) == lost_before + 4
		and ResourceManager.get_count(&"stone") == 6, "escaped gremlin got away with 4 stone (%.1fs)" % t)


## An idle or gathering hero fights a mob that comes close,
## then goes back to the gather; switched off, the hero leaves it be.
func _check_auto_attack(player: Node3D) -> void:
	var imp_def: MobDefinition = load("res://resources/mobs/shadow_imp.tres") as MobDefinition
	_check(GameSettings.auto_attack(), "auto-attack is on by default")
	var imp: Mob = _spawn_mob(imp_def, player.global_position + Vector3(2.0, 0, 0))
	imp.set_physics_process(false)
	await _wait(1.0)
	_check(imp.current_hp == imp_def.max_hp, "auto-attack off: the hero leaves the imp be")
	player.set("auto_attack", true)
	var t: float = 0.0
	while is_instance_valid(imp) and imp.current_hp == imp_def.max_hp and t < 3.0:
		await _wait(0.1)
		t += 0.1
	_check(not is_instance_valid(imp) or imp.current_hp < imp_def.max_hp, "an idle hero auto-attacks an imp 2 m away (%.1fs)" % t)
	if is_instance_valid(imp):
		imp.take_damage(999, player)
	await _wait(0.3)

	var bush: ResourceNode = _find_resource_node(&"berries")
	player.global_position = bush.global_position + Vector3(1.2, 0, 0)
	await _wait(0.1)
	_check((player as Hero).start_gather(bush) and (player as Hero).is_gathering(), "gathering a bush")
	imp = _spawn_mob(imp_def, player.global_position + Vector3(0, 0, 2.0))
	imp.set_physics_process(false)
	await _wait(0.5)
	_check((player as Hero).is_attacking() and player.get("command_target") == imp, "a close imp interrupts the gather")
	imp.take_damage(999, player)
	t = 0.0
	while not (player as Hero).is_gathering() and t < 4.0:
		await _wait(0.1)
		t += 0.1
	_check((player as Hero).gather_target() == bush, "then the hero goes back to the bush (%.1fs)" % t)
	(player as Hero).cancel_gather()
	player.set("auto_attack", false)


## A placed building is a blueprint that does nothing until
## the hero walks over and hammers it up; an unstarted one refunds.
func _check_construction(player: Node3D, companion: Node3D) -> void:
	var crate_def: BuildingDefinition = BuildManager.get_definition(&"storage_crate")
	var cap_before: int = ResourceManager.get_cap(&"wood")
	var spot: Transform3D = Transform3D(Basis(), player.global_position + Vector3(4.0, 0, 0))
	var refund: Building = BuildManager.place_blueprint(crate_def, Transform3D(Basis(), player.global_position + Vector3(-4.0, 0, 3.0)))
	var stone_before: int = ResourceManager.get_count(&"stone")
	_check(BuildManager.remove_blueprint(refund) and ResourceManager.get_count(&"stone") == stone_before + int(crate_def.cost[&"stone"]),
		"an unstarted blueprint comes back with a full refund")
	await get_tree().process_frame
	var xp_before: int = ProgressionManager.get_xp(player)
	var crate: Building = BuildManager.place_blueprint(crate_def, spot)
	await get_tree().process_frame
	_check(crate.is_blueprint() and not crate.is_in_group(ResourceManager.STORAGE_GROUP) and ResourceManager.get_cap(&"wood") == cap_before,
		"a fresh blueprint does nothing yet")
	var ghost: Node3D = crate.get_node_or_null("Ghost") as Node3D
	var ghost_material: ShaderMaterial = crate.get("_ghost_material") as ShaderMaterial
	_check(ghost != null and ghost_material != null and crate.get_node_or_null("Site") != null and crate.current_hp < crate_def.max_hp,
		"it shows as a blue ghost on a staked-out site, with less HP")
	var clip_start: float = float(ghost_material.get_shader_parameter("clip_y")) if ghost_material != null else 0.0
	var visual: CharacterVisual = player.get_node("Visual") as CharacterVisual
	var hits_before: int = int(player.call("build_hits"))
	var t: float = 0.0
	var hammered: bool = false
	var hammer_out: bool = false
	var clip_rose: bool = false
	while crate.is_blueprint() and t < 15.0:
		await _wait(0.1)
		t += 0.1
		hammered = hammered or bool(player.call("is_building"))
		hammer_out = hammer_out or visual.tool_shown() == &"hammer"
		if ghost_material != null and crate.is_blueprint():
			clip_rose = clip_rose or float(ghost_material.get_shader_parameter("clip_y")) > clip_start + 0.2
	_check(hammered and crate.is_built(), "the idle hero walks over and builds it (%.1fs for %.0fs of work)" % [t, crate_def.build_seconds])
	_check(hammer_out and int(player.call("build_hits")) > hits_before and clip_rose,
		"with a hammer in hand (%d blows landed), the solid part rising inside the ghost" % (int(player.call("build_hits")) - hits_before))
	await _wait(0.6)
	_check(crate.get_node_or_null("Ghost") == null and crate.get_node_or_null("Site") == null and visual.tool_shown() == &""
		and crate.current_hp == crate_def.max_hp, "built: ghost and site gone, hammer away, full HP")
	_check(ResourceManager.get_cap(&"wood") > cap_before and ProgressionManager.get_xp(player) >= xp_before + BuildManager.BUILD_XP_REWARD,
		"then it works, and the build XP comes on completion")
	# The companion's Repair task builds too.
	player.global_position = Vector3(-14, 0, -14)
	player.set_physics_process(false)
	var fence: Building = BuildManager.place_blueprint(BuildManager.get_definition(&"wooden_fence"), Transform3D(Basis(), companion.global_position + Vector3(0, 0, 2.5)))
	companion.call("set_task", Companion.Task.REPAIR)
	var helper: CharacterVisual = companion.get_node("Visual") as CharacterVisual
	var gear: Array[Node3D] = []
	for part in helper.tool_hidden_parts:
		var node: Node3D = helper.model.find_child(part, true, false) as Node3D
		if node != null:
			gear.append(node)
	var helper_hammer: bool = false
	var gear_away: bool = not gear.is_empty()
	t = 0.0
	while is_instance_valid(fence) and fence.is_blueprint() and t < 12.0:
		await _wait(0.1)
		t += 0.1
		if helper.tool_shown() == &"hammer":
			helper_hammer = true
			for node in gear:
				gear_away = gear_away and not node.visible
	_check(is_instance_valid(fence) and fence.is_built(), "on Repair the companion builds blueprints too (%.1fs)" % t)
	_check(helper_hammer and gear_away, "the companion builds with the mallet, %s put away" % ", ".join(helper.tool_hidden_parts))
	companion.call("set_task", Companion.Task.IDLE)
	await _wait(0.3)
	var gear_back: bool = helper.tool_shown() == &""
	for node in gear:
		gear_back = gear_back and node.visible
	_check(gear_back, "after building the mallet goes and the companion's own gear comes back")
	player.set_physics_process(true)
	crate.queue_free()
	if is_instance_valid(fence):
		fence.queue_free()
	await get_tree().process_frame


## Told to guard from behind a long wall, the companion
## walks round it on the nav mesh instead of pressing into it.
func _check_companion_unstuck(companion: Node3D) -> void:
	var nav: NavigationRegion3D = get_tree().current_scene.find_child("Navigation", true, false) as NavigationRegion3D
	var fire: Node3D = _campfire()
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 4
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(7.0, 2.0, 0.5)
	shape.shape = box
	shape.position.y = 1.0
	wall.add_child(shape)
	get_tree().current_scene.add_child(wall)
	wall.global_position = fire.global_position + Vector3(0, 0, -6.5)
	nav.call("_request_bake")  # rebake the nav mesh round it
	await nav.baked
	companion.call("set_task", Companion.Task.IDLE)
	companion.global_position = fire.global_position + Vector3(0.3, 0, -9.0)
	await _wait(0.2)
	companion.call("set_task", Companion.Task.GUARD_BASE)
	var t: float = 0.0
	var radius: float = float(companion.get("guard_radius"))
	while _flat(companion.global_position).distance_to(_flat(fire.global_position)) > radius + 0.3 and t < 12.0:
		await _wait(0.25)
		t += 0.25
	_check(t < 12.0, "guarding from behind a wall, the companion walks round it (%.1fs, %d hops)" % [t, int(companion.get("unstuck_count"))])
	companion.call("set_task", Companion.Task.IDLE)
	wall.queue_free()
	await get_tree().process_frame
	nav.call("_request_bake")  # and without it
	await nav.baked


## Waves mix in Bramble Beasts, which go for buildings.
func _check_bramble_beast(player: Node3D) -> void:
	var spawner: Node = get_tree().get_first_node_in_group("mob_spawner")
	# The Shadow Imp has its own clips.
	var imp: Mob = _spawn_mob(spawner.get("mob_definition"), Vector3(-14, 0, 18))
	await get_tree().process_frame
	var imp_visual: CharacterVisual = imp.get_node("Visual") as CharacterVisual
	var imp_player: AnimationPlayer = imp_visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var imp_missing: Array = []
	for state in imp_visual.clips.keys():
		if not imp_player.has_animation(String(imp_visual.clips[state])):
			imp_missing.append(imp_visual.clips[state])
	_check(imp_missing.is_empty(), "imp model has all its clips %s" % [imp_missing])
	# Defeated with no attacker (so no XP for Leo): it tumbles over and its
	# corpse is gone within CORPSE_SECONDS.
	imp.take_damage(999, null)
	await _wait(2.0)
	_check(not is_instance_valid(imp), "a defeated imp's corpse is cleared")
	var beast_def: MobDefinition = spawner.get("heavy_definition")
	_check(beast_def != null and beast_def.prefers_buildings, "spawner has a siege mob (bramble beast)")
	for night in [1, 2, 3]:
		var wave: Array = spawner.build_wave(night)
		var beasts: int = wave.count(beast_def)
		var sneaks: int = wave.count(spawner.get("sneak_definition"))
		_check(beasts == spawner.get_heavy_count(night) and sneaks == spawner.get_sneak_count(night)
			and wave.size() == spawner.get_wave_size(night) + beasts + sneaks,
			"night %d wave: %d imps + %d beasts + %d gremlins" % [night, wave.size() - beasts - sneaks, beasts, sneaks])
		if beasts > 0:
			_check(wave.find(beast_def) >= wave.size() / 2 - 1, "night %d: beasts come in the second half" % night)

	# A beast walks past Leo to tear down the nearest fence, hitting hard.
	var fence_def: BuildingDefinition = BuildManager.get_definition(&"wooden_fence")
	var fence: Building = fence_def.get_scene().instantiate() as Building
	get_tree().current_scene.add_child(fence)
	fence.global_position = Vector3(-8, 0, 14)
	var beast: Mob = beast_def.get_scene().instantiate() as Mob
	get_tree().current_scene.add_child(beast)
	beast.global_position = Vector3(-8, 0, 17.5)
	player.global_position = Vector3(-11, 0, 16)
	player.call("stop_commands")
	var t: float = 0.0
	while fence.current_hp == fence_def.max_hp and t < 15.0:
		await _wait(0.25)
		t += 0.25
	var expected_hit: int = int(round(beast_def.attack_damage * beast_def.building_damage_multiplier))
	_check(fence_def.max_hp - fence.current_hp == expected_hit, "beast hit the fence for %d (%.1fs)" % [fence_def.max_hp - fence.current_hp, t])
	_check(beast.get("_chase_target") == null, "beast ignored Leo 3 m away")
	var knocked_from: Vector3 = beast.global_position
	beast.take_damage(1, player)
	await _wait(0.3)
	_check(beast.global_position.distance_to(knocked_from) < 0.25, "beast barely flinches from hits")

	# Its own clips, and a telegraphed slam.
	var visual: CharacterVisual = beast.get_node("Visual") as CharacterVisual
	var player_anim: AnimationPlayer = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var missing: Array = []
	for state in visual.clips.keys():
		if not player_anim.has_animation(String(visual.clips[state])):
			missing.append(visual.clips[state])
	_check(missing.is_empty(), "beast model has all its clips %s" % [missing])
	# Hold the beast's own attacks so only the timed ones below land.
	beast.set("_attack_cooldown_remaining", 99.0)
	await _wait(1.0)
	beast.set("_attack_cooldown_remaining", 0.0)
	var before: int = fence.current_hp
	beast.call("_try_attack", fence)
	# Timed in game time, frame by frame: a fixed wait half-way through the
	# windup can end in a long frame that also carries the impact.
	var windup: float = 0.0
	while fence.current_hp == before and windup < beast_def.attack_hit_delay + 0.25:
		await get_tree().process_frame
		windup += get_process_delta_time()
	_check(windup >= beast_def.attack_hit_delay - 0.01, "the slam has not landed during the windup")
	_check(fence.current_hp < before, "the slam lands at impact (%.2fs)" % beast_def.attack_hit_delay)
	# A kid who steps away during the windup is not hit.
	beast.set("_attack_cooldown_remaining", 99.0)
	await _wait(0.5)
	player.global_position = beast.global_position + Vector3(1.0, 0, 0)
	var leo_hp: int = player.get("current_hp")
	beast.set("_attack_cooldown_remaining", 0.0)
	beast.call("_try_attack", player)
	player.global_position = beast.global_position + Vector3(4.0, 0, 0)
	await _wait(beast_def.attack_hit_delay + 0.25)
	_check(int(player.get("current_hp")) == leo_hp, "Leo dodged the slam by stepping away")
	beast.take_damage(999, player)
	fence.queue_free()
	await _wait(0.2)


## Actions layer over locomotion. While Leo runs, a swing
## plays on the upper body and the legs keep running; standing still it
## plays on the whole body.
func _check_animation_layers(player: Node3D) -> void:
	var visual: CharacterVisual = player.get_node("Visual") as CharacterVisual
	var tree: AnimationTree = visual.get_animation_tree()
	_check(tree != null and tree.active, "Leo has an active animation tree")
	player.command_move(player.global_position + Vector3(8, 0, 0))
	await _wait(0.4)
	_check(visual.is_moving() and float(tree.get("parameters/loco/blend_position")) > 1.0,
		"running blends the locomotion (%.1f)" % float(tree.get("parameters/loco/blend_position")))
	visual.play_action(&"attack", 1.9)
	_check(await _first_action_layer(visual) == "upper", "a swing while running plays on the upper body")
	player.stop_commands()
	await _wait(0.8)
	visual.play_action(&"attack", 1.9)
	_check(not visual.is_moving() and await _first_action_layer(visual) == "full", "a swing standing still plays on the whole body")
	await _wait(0.6)

	# Footsteps, swaying foliage, day ambience.
	_check(visual.steps_puffed > 0, "running kicks up footstep dust (%d puffs)" % visual.steps_puffed)
	var tree_node: ResourceNode = _find_resource_node(&"wood")
	var swaying: bool = false
	for mesh in tree_node.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mesh as MeshInstance3D
		var leaf: ShaderMaterial = m.get_surface_override_material(0) as ShaderMaterial if m.mesh != null else null
		if leaf != null and leaf.shader == Stylize.FOLIAGE_SHADER:
			swaying = true
	_check(swaying, "trees use the swaying foliage material")
	var ambience: WorldAmbience = get_tree().current_scene.find_child("WorldAmbience", true, false) as WorldAmbience
	_check(ambience != null and ambience.leaves.emitting and not ambience.fireflies.emitting, "day: leaves drift, no fireflies")


func _survive_night(night: int, player: Node3D) -> void:
	# Fast-forward: day -> sunset -> night.
	while TimeManager.current_phase != TimeManager.Phase.NIGHT:
		TimeManager.skip_phase()
	_check(AudioManager.mood == &"night", "night %d: night music mood" % night)
	var ambience: WorldAmbience = get_tree().current_scene.find_child("WorldAmbience", true, false) as WorldAmbience
	_check(ambience != null and ambience.fireflies.emitting and not ambience.leaves.emitting, "night %d: fireflies come out" % night)
	await _wait(0.2)
	_check(AudioManager.current_music() == AudioManager.library.music_night, "night %d: night track playing" % night)
	# Let the imps arrive and hit things for a few seconds, then clear
	# every imp as it appears. Killing the whole wave brings dawn early.
	var kills_before: int = int(GameManager.stats[&"kills"])
	var elapsed: float = 0.0
	while TimeManager.current_phase == TimeManager.Phase.NIGHT and elapsed < 120.0:
		await _wait(0.5)
		elapsed += 0.5
		if elapsed > 6.0:
			for mob in get_tree().get_nodes_in_group("mobs"):
				mob.take_damage(999, player)
	_check(elapsed < TimeManager.night_seconds, "night %d ended early by clearing the wave (%.1fs)" % [night, elapsed])
	_check(int(GameManager.stats[&"kills"]) > kills_before, "night %d: player got kills" % night)
	_check(int(GameManager.stats[&"nights_survived"]) == night, "night %d counted as survived" % night)
	print("smoke: night %d cleared, campfire hp=%d" % [night, _campfire().current_hp])


## The layer a just-started action plays on, read on the first physics
## frame the animation tree shows it (it updates on physics frames). A
## fixed frame count can outlast the whole short swing on a slow machine.
func _first_action_layer(visual: CharacterVisual) -> String:
	for i in 30:
		await get_tree().physics_frame
		var layer: String = visual.active_action_layer()
		if layer != "":
			return layer
	return ""
