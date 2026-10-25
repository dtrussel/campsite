extends Node

## Captures screenshots of the key screens for visual review. Needs a
## real renderer (not --headless), e.g. under xvfb-run.

const OUT_DIR: String = "user://screenshots/"
var _out: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_out = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(_out)
	# A sample autosave so the title shows Continue.
	SaveManager.set_save_path("user://screenshot_save.json")
	var sample: FileAccess = FileAccess.open("user://screenshot_save.json", FileAccess.WRITE)
	sample.store_string(SaveManager.serialize({"nights_to_win": 7, "day": 3, "inventory": {}, "campfire": {"hp": 150, "hearth": false},
		"buildings": [], "player": {"xp": 0, "stick": false}, "sibling": {"xp": 0, "slingshot": false, "task": 0}, "stats": {}}))
	sample.close()
	var title: Node = load("res://scenes/ui/TitleScreen.tscn").instantiate()
	add_child(title)
	await _settle(0.5)
	_shot("01_title")
	# The scrapbook's Badges tab, a few badges earned.
	Profile.set_path("user://screenshot_profile.json")
	Profile.delete()
	for id in [&"first_night", &"night_owl", &"builder", &"chapter_1", &"torch_bearer", &"gatherer"]:
		Profile.grant_badge_for_tests(id)
	for page in [&"ranger_log", &"old_lantern", &"rangers_map", &"bits_of_moon", &"lost_things"]:
		Journal.find(page)
	(title.call("journal_button") as Button).pressed.emit()
	await _settle(0.5)
	_shot("01a_scrapbook_badges")
	# The Journal tab, five pages found, one open.
	var scrapbook: Node = title.call("scrapbook")
	scrapbook.call("show_tab", "Journal")
	scrapbook.call("show_page", &"lost_things")
	await _settle(0.5)
	_shot("01a_scrapbook_journal")
	Profile.delete()
	title.queue_free()
	# The title with Chapter 2 locked (a new player in
	# a release build), then unlocked once Chapter 1 is won.
	var debug_unlock: bool = Profile.unlock_all_chapters
	Profile.unlock_all_chapters = false
	var locked_title: Node = load("res://scenes/ui/TitleScreen.tscn").instantiate()
	add_child(locked_title)
	await _settle(0.5)
	_shot("01_title_chapter2_locked")
	locked_title.queue_free()
	Profile.record_chapter_won(1)
	var unlocked_title: Node = load("res://scenes/ui/TitleScreen.tscn").instantiate()
	add_child(unlocked_title)
	await _settle(0.5)
	_shot("01_title_chapter2_unlocked")
	unlocked_title.queue_free()
	Profile.delete()
	Profile.unlock_all_chapters = debug_unlock
	SaveManager.delete_save()
	# The loading screens, one per painting.
	for i in LoadingScreen.SCREENS.size():
		var loading: LoadingScreen = LoadingScreen.preview(0.6, i)
		add_child(loading)
		await _settle(0.3)
		_shot("01b_loading_%d" % i)
		loading.queue_free()
	# The hero select screen, with each hero picked.
	var select: Node = load("res://scenes/ui/HeroSelect.tscn").instantiate()
	add_child(select)
	await _settle(1.5)
	_shot("01c_hero_select_leo")
	select.call("select", 1)
	await _settle(1.5)
	_shot("01d_hero_select_nela")
	select.queue_free()
	# The Chapter 1 intro storybook (first and Mum's page).
	var book: StoryBook = StoryBook.play(StoryLibrary.find(&"intro", 1), &"leo")
	await _settle(1.5)
	_shot("01e_intro_page_1")
	book.next()
	book.next()
	await _settle(1.5)
	_shot("01f_intro_page_3")
	book.skip()
	await _settle(0.5)

	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await _settle(0.5)
	_shot("02_controls_overlay")
	get_tree().get_first_node_in_group("controls_overlay").close()
	var player: Node3D = get_tree().get_first_node_in_group("player")
	await _settle(1.0)
	_shot("03_day_hud")
	# The camera tilts as it zooms in; the three blur levels.
	var rig: Node = get_tree().get_first_node_in_group("camera_rig")
	rig.set("_zoom_target", rig.get("min_zoom"))
	await _settle(1.0)
	_shot("03d_zoom_close")
	# The team's Moon Lantern by day, still dark.
	var day_spot: Vector3 = player.global_position
	player.global_position = MoonLantern.find(get_tree()).global_position + Vector3(1.6, 0, 1.2)
	await _settle(1.5)
	_shot("03g_moon_lantern_day")
	player.global_position = day_spot
	rig.set("_zoom_target", 1.0)
	await _settle(1.0)
	for level in [PostFx.Blur.OFF, PostFx.Blur.STRONG, PostFx.Blur.SOFT]:
		PostFx.set_blur_level(level)
		await _settle(0.3)
		_shot("03e_blur_%s" % PostFx.BLUR_NAMES[level].to_lower())
	# A call and response over both kids' heads.
	var director: BarkDirector = get_tree().get_first_node_in_group("bark_director") as BarkDirector
	await _settle(2.5)  # past the DAY banner
	director.clock += 60.0
	director.bark(&"thief")
	var companion: Node = get_tree().get_first_node_in_group("companions")
	for i in 40:  # until Nela's reply is up (frames are slow under xvfb)
		if SpeechBubble.on(companion) != null:
			break
		await _settle(0.1)
	await _settle(0.3)
	_shot("03c_barks")
	# A dawn story card over the HUD, with the lantern hint.
	var hud: Node = main.get_node("HUD")
	var card: StoryCard = hud.call("show_story", StoryLibrary.first(&"dawn", 1, 1), hud.call("_lantern_hint"))
	await _settle(1.5)
	_shot("03b_dawn_card")
	card.dismiss()
	# A Chapter 2 dawn card with one of Mum's notes, and a
	# creature's first banner saying what it is.
	await _settle(0.8)
	card = hud.call("show_story", StoryLibrary.first(&"dawn", 2, 2), "")
	await _settle(1.5)
	_shot("03b2_dawn_note")
	if card != null:
		card.dismiss()
	hud.call("_on_mob_spawned", player, load("res://resources/mobs/bramble_beast.tres"))
	await _settle(2.0)  # the banner fades in, and xvfb renders slowly
	_shot("03f_creature_banner")

	ResourceManager.add(&"wood", 9)
	# The crafting items, so the tray, recipes and build chips light up.
	for item in [&"clay", &"stone", &"berries", &"scrap", &"glow_shards"]:
		ResourceManager.add(item, 5)
	var fire: Node = get_tree().get_first_node_in_group("base_core")
	fire.take_damage(30)
	player.global_position = Vector3(1.5, 0, 1.5)
	await _settle(1.0)
	get_tree().get_first_node_in_group("crafting_panel").open()
	await _settle(0.3)
	_shot("04_crafting")
	get_tree().get_first_node_in_group("crafting_panel").close()

	# Build flow through the real mouse raycast.
	BuildManager.enter_build_mode(BuildManager.get_definition(&"wooden_fence"))
	get_viewport().warp_mouse(Vector2(820, 470))
	await _settle(0.5)
	print("build: ghost valid=", BuildManager.get("_is_valid"))
	_shot("04b_build_ghost")
	var placed: Array = []
	BuildManager.building_placed.connect(func(b: Node) -> void: placed.append(b))
	BuildManager.call("_try_confirm")
	print("build: placed=", placed.size(), " wood_left=", ResourceManager.get_count(&"wood"))
	BuildManager.exit_build_mode()
	get_viewport().warp_mouse(Vector2(200, 640))  # no hover highlight on the site
	# The hero walks over and hammers the blueprint up.
	if not placed.is_empty():
		var site: Building = placed[0] as Building
		await _settle(0.2)
		_shot("04b1_blueprint_fresh")
		for i in 200:
			if site.build_progress >= 0.4:
				break
			await _settle(0.05)
		_shot("04b2_blueprint_building")
		site.complete_construction(player)
		# The finish tweens need a few frames, and xvfb renders only a few a second.
		for i in 60:
			if site.get_node_or_null("Site") == null and site.get_node_or_null("Ghost") == null:
				break
			await _settle(0.1)
		_shot("04b4_blueprint_done")
		# Zoomed in on the hero mid-blow on a watch post.
		var cam_rig: Node = get_tree().get_first_node_in_group("camera_rig")
		cam_rig.set("_zoom_target", cam_rig.get("min_zoom"))
		var post: Building = BuildManager.place_blueprint(BuildManager.get_definition(&"watch_post"),
			Transform3D(Basis(), player.global_position + Vector3(2.2, 0, 0.6)))
		for i in 200:
			if post.build_progress >= 0.45:
				break
			await _settle(0.05)
		var hits: int = int(player.call("build_hits"))
		for i in 300:
			if post.build_progress < 0.4:
				hits = int(player.call("build_hits"))
			elif int(player.call("build_hits")) > hits or post.build_progress > 0.8:
				break
			await _settle(0.02)
		_shot("04b3_build_close")
		post.complete_construction(player)
		post.queue_free()
		# Side on, so the hammer reads.
		player.global_position = Vector3(1.0, 0, 6.0)
		var side: Building = BuildManager.place_blueprint(BuildManager.get_definition(&"reinforced_wall"),
			Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(2.6, 0, 6.0)))
		for i in 200:
			if side.build_progress >= 0.1:
				break
			await _settle(0.05)
		var side_hits: int = int(player.call("build_hits"))
		for i in 100:
			if int(player.call("build_hits")) > side_hits:
				break
			await _settle(0.02)
		_shot("04b5_hammer")
		side.complete_construction(player)
		side.queue_free()
		cam_rig.set("_zoom_target", 1.0)
		await _settle(0.6)
		get_viewport().warp_mouse(Vector2(820, 470))

	# The Stone Hearth, a snap trap and a glow lantern by the fire,
	# and a glow shard pickup lying in the grass.
	CraftingManager.craft(_recipe(&"stone_hearth"), player)
	for spec in [["res://scenes/buildings/SnapTrap.tscn", Vector3(3.2, 0, 3.5)],
			["res://scenes/buildings/ReinforcedWall.tscn", Vector3(4.5, 0, -1.0)],
			["res://scenes/buildings/StorageCrate.tscn", Vector3(-4.6, 0, 1.8)],
			["res://scenes/buildings/CraftingTable.tscn", Vector3(2.0, 0, -4.5)],
			["res://scenes/buildings/GlowLantern.tscn", Vector3(-3.0, 0, 3.8)],
			["res://scenes/world/ItemPickup.tscn", Vector3(0.5, 0, 5.0)]]:
		var extra: Node3D = (load(spec[0]) as PackedScene).instantiate() as Node3D
		get_tree().current_scene.add_child(extra)
		extra.global_position = spec[1]
	player.global_position = Vector3(0.5, 0, 2.2)
	get_tree().get_first_node_in_group("companions").call("set_task", Companion.Task.REPAIR)
	await _settle(1.0)
	_shot("04c_feature_017")
	# The Crafting Table's own recipes, and a full stash.
	ResourceManager.add(&"wood", 100)
	player.global_position = Vector3(2.0, 0, -3.2)
	await _settle(0.3)
	get_tree().get_first_node_in_group("crafting_panel").open()
	await _settle(0.3)
	_shot("04e_table_recipes")
	get_tree().get_first_node_in_group("crafting_panel").close()
	# Leo owns the Ember Stick, so the Blaze Stick
	# (tier 3) is offered; then the HUD attack slot's three tier pips.
	(player as Hero).set_tool_tier(2, true)
	for item in [&"scrap", &"clay", &"glow_shards"]:
		ResourceManager.add(item, 6)
	await _settle(0.3)
	get_tree().get_first_node_in_group("crafting_panel").open()
	await _settle(0.3)
	_shot("04e2_tier_3_available")
	get_tree().get_first_node_in_group("crafting_panel").close()
	# Raised directly: crafting it gives XP, and the level-up picker
	# would cover the HUD.
	(player as Hero).set_tool_tier(3, true)
	await _settle(0.5)
	_shot("04e3_tier_pips")
	player.global_position = Vector3(0.5, 0, 2.2)
	BuildManager.enter_build_mode(BuildManager.get_definition(&"glow_lantern"))
	await _settle(0.4)
	_shot("04d_build_lantern")
	BuildManager.exit_build_mode()
	CraftingManager.craft(CraftingManager.get_recipes()[0], player)
	player.call("try_place_torch")
	var fence: Node3D = BuildManager.get_definition(&"wooden_fence").get_scene().instantiate()
	get_tree().current_scene.add_child(fence)
	fence.global_position = Vector3(0, 0, -3)

	while TimeManager.current_phase != TimeManager.Phase.SUNSET:
		TimeManager.skip_phase()
	await _settle(0.3)
	_shot("05_sunset")
	TimeManager.skip_phase()
	# A Bramble Beast lumbering toward the fence.
	var beast: Node3D = (load("res://scenes/mobs/BrambleBeast.tscn") as PackedScene).instantiate() as Node3D
	get_tree().current_scene.add_child(beast)
	beast.global_position = Vector3(6.5, 0, 7.5)
	# A Mushroom Gremlin, and the loot a caught one dropped.
	var gremlin: Node3D = (load("res://scenes/mobs/MushroomGremlin.tscn") as PackedScene).instantiate() as Node3D
	get_tree().current_scene.add_child(gremlin)
	gremlin.global_position = Vector3(1.8, 0, 6.2)
	gremlin.set_physics_process(false)  # hold still for the picture
	var loot: Node3D = (load("res://scenes/world/ItemPickup.tscn") as PackedScene).instantiate() as Node3D
	loot.set("item_id", &"stone")
	loot.set("amount", 4)
	get_tree().current_scene.add_child(loot)
	loot.global_position = Vector3(-2.5, 0, 5.5)
	Engine.time_scale = 3.0
	await get_tree().create_timer(4.0, true, false, true).timeout
	Engine.time_scale = 1.0
	player.call("_try_attack")
	await _settle(0.1)
	_shot("06_night_wave")
	# The Moon Lantern at stage 2 of 3, its ring and dial.
	var lantern: MoonLantern = MoonLantern.find(get_tree())
	lantern.restore(6)
	var spot: Vector3 = player.global_position
	if hud.call("story_card") != null:
		hud.call("story_card").dismiss()
	player.global_position = lantern.global_position + Vector3(2.2, 0, 0.8)
	await _settle(2.0)
	_shot("06b_moon_lantern")
	# The team's lantern, fully lit, up close.
	lantern.restore(lantern.shards_for_max())
	rig.set("_zoom_target", rig.get("min_zoom"))
	await _settle(2.0)
	_shot("06c_moon_lantern_full")
	rig.set("_zoom_target", 1.0)
	player.global_position = spot
	await get_tree().create_timer(3.0, true, false, true).timeout
	_shot("07_night_later")
	# Perk cards: the level-up picker over the night. A fixed deal.
	PerkManager.rng.seed = 3
	ProgressionManager.award_xp(player, ProgressionManager.get_xp_to_next_level(player), &"screenshot")
	await _settle(0.8)
	_shot("07c_perk_picker")
	PerkManager.close_picker()
	await _settle(0.4)
	# The remodelled Shadow Imp up close, next to Leo.
	for offset in [Vector3(-1.4, 0, 1.2), Vector3(1.5, 0, 1.0)]:
		var imp: Node3D = (load("res://scenes/mobs/ShadowImp.tscn") as PackedScene).instantiate() as Node3D
		get_tree().current_scene.add_child(imp)
		imp.global_position = player.global_position + offset
		imp.set_physics_process(false)
	await _settle(2.2)  # past the rise-from-the-ground animation
	_shot("07b_imp_closeup")
	var pause: Node = main.get_node("PauseMenu")
	pause.get("_root").visible = true
	await _settle(0.2)
	_shot("08_pause")
	pause.get("_root").visible = false
	_campfire_out()
	await _settle(0.5)
	_shot("09_end_screen")
	# The Chapter 1 ending page.
	var ending: StoryBook = StoryBook.play(StoryLibrary.find(&"win", 1), &"leo", 30)
	await _settle(1.5)
	_shot("09b_chapter_1_ending")
	ending.skip()
	await _settle(0.4)
	# Every storybook page with the team's paintings.
	for book_spec in [[&"intro", 1], [&"intro", 2], [&"win", 1], [&"win", 2]]:
		var pages: Array = StoryLibrary.find(book_spec[0], book_spec[1])
		var story: StoryBook = StoryBook.play(pages, &"nela" if book_spec[1] == 1 and book_spec[0] == &"intro" else &"leo", 30)
		await _settle(1.2)
		for i in pages.size():
			_shot("14_story_%s" % String((pages[i] as StoryBeat).id).replace(".", "_"))
			story.next()
			await _settle(1.2)
		if is_instance_valid(story):
			story.skip()
		await _settle(0.4)
	# A run playing Nela, with Leo as the companion.
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var nela_run: RunConfig = RunConfig.for_chapter(1)
	nela_run.set_party(&"nela")
	RunSession.reset(nela_run)
	main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await _settle(0.5)
	get_tree().get_first_node_in_group("controls_overlay").close()
	await _settle(1.5)
	_shot("10_nela_hud")
	# The true ending - Mum walks out of the woods to the kids.
	var hero: Node3D = get_tree().get_first_node_in_group("player")
	var arrival: MumArrival = MumArrival.play(get_tree().current_scene, hero.global_position)
	await _settle(3.0)
	_shot("11_mum_arrives")
	await arrival.finished
	await _settle(0.4)
	_shot("11b_mum_waves")
	arrival.queue_free()
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# The Moon-Eater on Chapter 2's last night.
	get_tree().paused = false
	RunSession.reset(RunConfig.for_chapter(2))
	main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await _settle(0.5)
	get_tree().get_first_node_in_group("controls_overlay").close()
	var lantern_7: MoonLantern = MoonLantern.find(get_tree())
	lantern_7.restore(lantern_7.shards_for_max())
	hero = get_tree().get_first_node_in_group("player")
	hero.global_position = Vector3(-2.0, 0, -12.0)
	TimeManager.day_number = 7
	while not TimeManager.is_night():
		TimeManager.skip_phase()
	var boss: BossController = null
	while boss == null:
		await _settle(0.2)
		boss = BossController.find(get_tree())
	await _settle(1.4)
	_shot("13_boss_rise")
	while boss.phase == BossController.Phase.RISING:
		await _settle(0.2)
	boss.set_physics_process(false)
	for node in get_tree().get_nodes_in_group("mobs"):
		if node != boss:
			node.queue_free()
	boss.global_position = Vector3(3.0, 0, 1.5)
	boss.get_node("Visual").call("face_instantly", Vector3(-0.6, 0, 1.0))
	hero.global_position = Vector3(-0.5, 0, -1.0)
	boss.take_damage(260, hero)
	await _settle(0.8)
	boss.stomp()
	await _settle(0.5)
	_shot("13b_boss_stomp")
	await _settle(2.0)
	_shot("13c_boss_bar")
	var done: Array = [false]
	boss.defeated.connect(func(_b: Node) -> void: done[0] = true)
	boss.take_damage(99999, hero)
	while get_tree().get_first_node_in_group(MoonEaterVisual.PILE_GROUP) == null:  # slow frames under xvfb
		await _settle(0.1)
	await _settle(0.5)
	_shot("13d_boss_falls_apart")
	await _settle(0.9)
	_shot("13d2_boss_lets_moon_go")
	while not done[0]:  # the shrink and the walk to the fire (slow frames under xvfb)
		await _settle(0.2)
	_shot("13e_boss_warm_shadow")
	main.queue_free()
	RunSession.forget_last_run()
	# ...and after the true ending Mum sits by the title fire.
	Profile.set_path("user://screenshot_profile.json")
	StoryLibrary.mark_seen(StoryLibrary.TRUE_ENDING)
	var home: Node = load("res://scenes/ui/TitleScreen.tscn").instantiate()
	add_child(home)
	await _settle(1.0)
	_shot("12_title_mum_home")
	home.queue_free()
	# The Endless button with its record...
	Profile.record_endless(12, &"nela")
	var endless_title: Node = load("res://scenes/ui/TitleScreen.tscn").instantiate()
	add_child(endless_title)
	await _settle(1.0)
	_shot("15_title_endless_record")
	endless_title.queue_free()
	# ...and an endless run that beats it: "New record!".
	RunSession.reset(RunConfig.for_endless())
	var endless_main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(endless_main)
	await _settle(0.5)
	get_tree().get_first_node_in_group("controls_overlay").close()
	await _settle(0.5)
	TimeManager.day_number = 14
	GameManager.current_day = 14
	GameManager.stats[&"nights_survived"] = 13
	_campfire_out()
	await _settle(0.8)
	_shot("15b_end_screen_new_record")
	endless_main.queue_free()
	RunSession.forget_last_run()
	Profile.delete()
	get_tree().quit(0)


func _campfire_out() -> void:
	get_tree().get_first_node_in_group("base_core").take_damage(10000)


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
	await RenderingServer.frame_post_draw


func _shot(label: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_out.path_join(label + ".png"))
	print("screenshot: ", label)


func _recipe(id: StringName) -> CraftingRecipe:
	for recipe in CraftingManager.get_recipes():
		if recipe.id == id:
			return recipe
	return null
