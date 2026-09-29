extends Node

## Captures screenshots of the key screens for visual review. Needs a
## real renderer (not --headless), e.g. under xvfb-run.

const OUT_DIR: String = "user://screenshots/"
var _out: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_out = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(_out)
	var title: Node = load("res://scenes/ui/TitleScreen.tscn").instantiate()
	add_child(title)
	await _settle(0.5)
	_shot("01_title")
	title.queue_free()

	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await _settle(0.5)
	_shot("02_controls_overlay")
	get_tree().get_first_node_in_group("controls_overlay").close()
	var player: Node3D = get_tree().get_first_node_in_group("player")
	await _settle(1.0)
	_shot("03_day_hud")

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
	BuildManager.enter_build_mode(BuildManager.get_known_definitions()[0])
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
			["res://scenes/buildings/GlowLantern.tscn", Vector3(-3.0, 0, 3.8)],
			["res://scenes/world/ItemPickup.tscn", Vector3(0.5, 0, 5.0)]]:
		var extra: Node3D = (load(spec[0]) as PackedScene).instantiate() as Node3D
		get_tree().current_scene.add_child(extra)
		extra.global_position = spec[1]
	player.global_position = Vector3(0.5, 0, 2.2)
	get_tree().get_first_node_in_group("companions").call("set_task", 4)
	await _settle(1.0)
	_shot("04c_feature_017")
	BuildManager.enter_build_mode(BuildManager.get_known_definitions()[3])
	await _settle(0.4)
	_shot("04d_build_lantern")
	BuildManager.exit_build_mode()
	CraftingManager.craft(CraftingManager.get_recipes()[0], player)
	player.call("_try_place_torch")
	var fence: Node3D = BuildManager.get_known_definitions()[0].get_scene().instantiate()
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
	Engine.time_scale = 3.0
	await get_tree().create_timer(4.0, true, false, true).timeout
	Engine.time_scale = 1.0
	player.call("_try_attack")
	await _settle(0.1)
	_shot("06_night_wave")
	await get_tree().create_timer(3.0, true, false, true).timeout
	_shot("07_night_later")
	var pause: Node = main.get_node("PauseMenu")
	pause.get("_root").visible = true
	await _settle(0.2)
	_shot("08_pause")
	pause.get("_root").visible = false
	_campfire_out()
	await _settle(0.5)
	_shot("09_end_screen")
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
