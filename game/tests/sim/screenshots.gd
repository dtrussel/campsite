extends Node

## Captures screenshots of the key screens for visual review. Needs a
## real renderer (not --headless), e.g. under xvfb-run.

const OUT_DIR: String = "user://screenshots/"
var _out: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_out = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(_out)
	# A sample autosave so the title shows Continue (feature 020).
	SaveManager.set_save_path("user://screenshot_save.json")
	var sample: FileAccess = FileAccess.open("user://screenshot_save.json", FileAccess.WRITE)
	sample.store_string(SaveManager.serialize({"nights_to_win": 7, "day": 3, "inventory": {}, "campfire": {"hp": 150, "hearth": false},
		"buildings": [], "player": {"xp": 0, "stick": false}, "sibling": {"xp": 0, "slingshot": false, "task": 0}, "stats": {}}))
	sample.close()
	var title: Node = load("res://scenes/ui/TitleScreen.tscn").instantiate()
	add_child(title)
	await _settle(0.5)
	_shot("01_title")
	title.queue_free()
	SaveManager.delete_save()
	# Features 029-030: the loading screens, one per painting.
	for i in LoadingScreen.SCREENS.size():
		var loading: LoadingScreen = LoadingScreen.preview(0.6, i)
		add_child(loading)
		await _settle(0.3)
		_shot("01b_loading_%d" % i)
		loading.queue_free()
	# Feature 034: the hero select screen, with each hero picked.
	var select: Node = load("res://scenes/ui/HeroSelect.tscn").instantiate()
	add_child(select)
	await _settle(1.5)
	_shot("01c_hero_select_leo")
	select.call("select", 1)
	await _settle(1.5)
	_shot("01d_hero_select_nela")
	select.queue_free()
	# Feature 035: the Chapter 1 intro storybook (first and Mum's page).
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
	# Feature 035: a dawn story card over the HUD, with the lantern hint.
	var hud: Node = main.get_node("HUD")
	var card: StoryCard = hud.call("show_story", StoryLibrary.first(&"dawn", 1, 1), hud.call("_lantern_hint"))
	await _settle(1.5)
	_shot("03b_dawn_card")
	card.dismiss()

	ResourceManager.add(&"wood", 6)
	ResourceManager.add(&"resin", 2)
	ResourceManager.add(&"leaves", 2)
	ResourceManager.add(&"fiber", 3)
	# Feature 017 items, so the tray, recipes and build chips light up.
	for item in [&"clay", &"stone", &"berries", &"mushrooms", &"scrap", &"glow_shards"]:
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
	print("build: placed=", placed.size(), " fiber_left=", ResourceManager.get_count(&"fiber"))
	BuildManager.exit_build_mode()

	# Feature 017: the Stone Hearth, a snap trap and a glow lantern by the fire,
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
	get_tree().get_first_node_in_group("companions").call("set_task", 4)
	await _settle(1.0)
	_shot("04c_feature_017")
	# Feature 019: the Crafting Table's own recipes, and a full stash.
	ResourceManager.add(&"wood", 100)
	player.global_position = Vector3(2.0, 0, -3.2)
	await _settle(0.3)
	get_tree().get_first_node_in_group("crafting_panel").open()
	await _settle(0.3)
	_shot("04e_table_recipes")
	get_tree().get_first_node_in_group("crafting_panel").close()
	player.global_position = Vector3(0.5, 0, 2.2)
	BuildManager.enter_build_mode(BuildManager.get_definition(&"glow_lantern"))
	await _settle(0.4)
	_shot("04d_build_lantern")
	BuildManager.exit_build_mode()
	CraftingManager.craft(CraftingManager.get_recipes()[0], player)
	player.call("_try_place_torch")
	var fence: Node3D = BuildManager.get_definition(&"wooden_fence").get_scene().instantiate()
	get_tree().current_scene.add_child(fence)
	fence.global_position = Vector3(0, 0, -3)

	while TimeManager.current_phase != TimeManager.Phase.SUNSET:
		TimeManager.skip_phase()
	await _settle(0.3)
	_shot("05_sunset")
	TimeManager.skip_phase()
	# Feature 018: a Bramble Beast lumbering toward the fence.
	var beast: Node3D = (load("res://scenes/mobs/BrambleBeast.tscn") as PackedScene).instantiate() as Node3D
	get_tree().current_scene.add_child(beast)
	beast.global_position = Vector3(6.5, 0, 7.5)
	# Feature 021: a Mushroom Gremlin, and the loot a caught one dropped.
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
	# Feature 036: the Moon Lantern at stage 2 of 3, its ring and dial.
	var lantern: MoonLantern = MoonLantern.find(get_tree())
	lantern.restore(6)
	var spot: Vector3 = player.global_position
	if hud.call("story_card") != null:
		hud.call("story_card").dismiss()
	player.global_position = lantern.global_position + Vector3(2.2, 0, 0.8)
	await _settle(2.0)
	_shot("06b_moon_lantern")
	player.global_position = spot
	await get_tree().create_timer(3.0, true, false, true).timeout
	_shot("07_night_later")
	# Feature 022: the remodelled Shadow Imp up close, next to Leo.
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
	# Feature 035: the Chapter 1 ending page.
	var ending: StoryBook = StoryBook.play(StoryLibrary.find(&"win", 1), &"leo", 30)
	await _settle(1.5)
	_shot("09b_chapter_1_ending")
	ending.skip()
	await _settle(0.4)
	# Feature 034: a run playing Nela, with Leo as the companion.
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.call("_reset_autoloads")
	GameManager.set_party(&"nela")
	main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await _settle(0.5)
	get_tree().get_first_node_in_group("controls_overlay").close()
	await _settle(1.5)
	_shot("10_nela_hud")
	# Feature 043: the true ending - Mum walks out of the woods to the kids.
	var hero: Node3D = get_tree().get_first_node_in_group("player")
	var arrival: MumArrival = MumArrival.play(get_tree().current_scene, hero.global_position)
	await _settle(3.0)
	_shot("11_mum_arrives")
	await arrival.finished
	await _settle(0.4)
	_shot("11b_mum_waves")
	# ...and after it she sits by the title fire.
	main.queue_free()
	StoryLibrary.progress_path = "user://screenshot_story.cfg"
	StoryLibrary.mark_seen(StoryLibrary.TRUE_ENDING)
	var home: Node = load("res://scenes/ui/TitleScreen.tscn").instantiate()
	add_child(home)
	await _settle(1.0)
	_shot("12_title_mum_home")
	StoryLibrary.forget_progress()
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
