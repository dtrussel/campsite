extends Node

## smoke_run.gd
##
## End-to-end headless smoke test for the playtest loop. Instances the
## real Main scene and drives it through a whole run:
##   gather -> craft a torch -> plant it -> survive 3 nights -> win,
## then a second run that loses when the campfire is destroyed, a
## continued run, and a run playing Nela with Leo as the companion.
## Features 035-036: the story cards and storybook, the shard drops and
## the Moon Lantern. Feature 038: the Moon-Eater, Chapter 2's last night.
##
##   godot --headless --path game res://tests/automated/smoke_run.tscn
##
## Exits 0 on success, 1 on the first failed check (or on timeout).

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const TIMEOUT_SECONDS: float = 180.0
const SPEED: float = 4.0

var _main: Node = null
var _failures: int = 0
## The autosave written after night 1 of the win run (feature 020).
var _night1_save: Dictionary = {}

const TEST_SAVE_PATH: String = "user://smoke_save.json"
const TEST_STORY_PATH: String = "user://smoke_story.cfg"
const TEST_PROFILE_PATH: String = "user://smoke_profile.json"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(TIMEOUT_SECONDS, true, false, true).timeout.connect(func() -> void:
		_fail("timed out after %ds" % TIMEOUT_SECONDS)
		_finish()
	)
	# Never touch a real player's autosave.
	SaveManager.set_save_path(TEST_SAVE_PATH)
	SaveManager.delete_save()
	StoryLibrary.progress_path = TEST_STORY_PATH
	StoryLibrary.forget_progress()
	Profile.set_path(TEST_PROFILE_PATH)
	Profile.delete()
	await _run_story_scenario()
	await _run_win_scenario()
	await _run_loss_scenario()
	await _run_continue_scenario()
	await _run_blueprint_save_scenario()
	await _run_hero_scenario()
	await _run_bark_scenario()
	await _run_boss_scenario()
	await _run_perk_01_scenario()
	await _run_perk_02_scenario()
	await _run_perk_03_scenario()
	await _run_perk_06_scenario()
	await _run_perk_04_scenario()
	await _run_perk_05_scenario()
	await _run_perk_07_scenario()
	await _run_perk_review_scenario()
	await _run_hero_health_scenario()
	SaveManager.delete_save()
	StoryLibrary.forget_progress()
	Profile.delete()
	_finish()


## Feature 045: a half-built blueprint survives Continue as a blueprint,
## dressed again (ghost, site, build line at its progress), and the hero
## then finishes it.
func _run_blueprint_save_scenario() -> void:
	print("smoke: --- blueprint save scenario ---")
	await _start_fresh_run()
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var def: BuildingDefinition = BuildManager.get_definition(&"watch_post")
	var where: Vector3 = player.global_position + Vector3(3.5, 0, 2.0)
	var post: Building = BuildManager.place_blueprint(def, Transform3D(Basis(Vector3.UP, 0.6), where))
	player.set_physics_process(false)  # leave it half built
	post.add_build_progress(def.build_seconds * 0.5)
	await get_tree().process_frame
	var hp_before: int = post.current_hp
	var clip_before: float = float((post.get("_ghost_material") as ShaderMaterial).get_shader_parameter("clip_y"))
	var data: Dictionary = SaveManager.snapshot()
	GameManager.set("_pending_save", SaveManager.parse(SaveManager.serialize(data)))
	await _start_fresh_run()
	await get_tree().process_frame
	var loaded: Building = null
	for node in get_tree().get_nodes_in_group(Building.BLUEPRINT_GROUP):
		if node is Building and (node as Building).definition.id == &"watch_post":
			loaded = node as Building
	_check(loaded != null and is_equal_approx(loaded.build_progress, 0.5) and loaded.current_hp == hp_before
		and loaded.global_position.distance_to(where) < 0.01 and absf(loaded.global_rotation.y - 0.6) < 0.01,
		"Continue keeps a half-built watch post as a blueprint (50%%, %d HP, same spot)" % hp_before)
	if loaded == null:
		return
	var ghost_material: ShaderMaterial = loaded.get("_ghost_material") as ShaderMaterial
	var clip_after: float = float(ghost_material.get_shader_parameter("clip_y")) if ghost_material != null else -1000.0
	_check(loaded.get_node_or_null("Ghost") != null and loaded.get_node_or_null("Site") != null
		and absf(clip_after - clip_before) < 0.02 and not loaded.is_physics_processing(),
		"it comes back as a ghost on its site, the build line where it was (%.2f m), not shooting yet" % clip_after)
	player = get_tree().get_first_node_in_group("player")
	var t: float = 0.0
	while loaded.is_blueprint() and t < 12.0:
		await _wait(0.1)
		t += 0.1
	_check(loaded.is_built() and loaded.is_physics_processing(), "the hero finishes the loaded blueprint (%.1fs) and it works" % t)


## Closes any story card or story book that is up.
func _close_story() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	var card: StoryCard = hud.call("story_card") as StoryCard if hud != null else null
	if card != null:
		card.dismiss()  # fades, then frees itself
	for book in get_tree().get_nodes_in_group("story_book"):
		if (book as StoryBook).is_open():
			(book as StoryBook).skip()
	var t: float = 0.0
	while is_instance_valid(card) and t < 3.0:
		await _wait(0.1)
		t += 0.1
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

	# Gather from a tree: wood (playtest 1 cut the leaves bonus).
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
	player.call("_try_place_torch")
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

	await _check_feature_017(player, companion, fence)

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
	while int(player.get("command")) != 0 and t < 10.0:
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

	companion.call("set_task", 2)  # guard the campfire
	for night in range(1, GameManager.nights_to_win + 1):
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
		if night < GameManager.nights_to_win:
			_check(GameManager.is_playing(), "still playing after night %d" % night)
	_check(GameManager.run_state == GameManager.RunState.WON, "run WON after %d nights" % GameManager.nights_to_win)
	# Feature 035: the Chapter 1 ending book comes before the stats.
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


## Feature 035: the story data, the intro storybook and the chapters;
## feature 036: shard drops and the Moon Lantern.
func _run_story_scenario() -> void:
	print("smoke: --- story scenario ---")
	_check(StoryLibrary.chapter_name(1) == "The Dark Moon" and StoryLibrary.chapter_name(2) == "Into the Hollow", "chapter names")
	GameManager.nights_to_win = 7
	_check(GameManager.chapter() == 2, "7 nights is Chapter 2")
	GameManager.nights_to_win = 3
	_check(GameManager.chapter() == 1, "3 nights is Chapter 1")
	var pages: Array = StoryLibrary.find(&"intro", 1)
	_check(pages.size() == 4 and (pages[0] as StoryBeat).page == 1 and (pages[0] as StoryBeat).painting != null,
		"the Chapter 1 intro has 4 painted pages, in order")
	var dawn: StoryBeat = StoryLibrary.first(&"dawn", 1, 1)
	_check(String(dawn.lines_for(&"leo")[0]["speaker"]) == "leo" and String(dawn.lines_for(&"nela")[0]["speaker"]) == "nela",
		"the played hero speaks first on the dawn card")
	var book: StoryBook = StoryBook.play(pages, &"leo")
	await get_tree().process_frame
	var turned: Array = [false]
	book.finished.connect(func() -> void: turned[0] = true)
	_check(book.page == 0, "the intro opens on page 1")
	book.next()
	_check(book.page == 1, "Space turns the page")
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(turned[0], "Esc skips the rest of the intro")
	_check(not StoryLibrary.has_seen("intro.c1"), "no intro marked seen yet")
	StoryLibrary.mark_seen("intro.c1")
	_check(StoryLibrary.has_seen("intro.c1") and not StoryLibrary.has_seen("intro.c2"), "the seen intro is remembered per chapter")
	_check(GameManager.intro_pages().size() == 4, "a seen intro still opens the next new game")
	StoryLibrary.forget_progress()

	# Shards: a chance per kill with pity, per mob type (seeded).
	var imp_def: MobDefinition = load("res://resources/mobs/shadow_imp.tres") as MobDefinition
	var beast_def: MobDefinition = load("res://resources/mobs/bramble_beast.tres") as MobDefinition
	GameManager.loot_misses = {}
	GameManager.loot_rng.seed = 36
	var hits: int = 0
	var longest_dry: int = 0
	var dry: int = 0
	for i in 100:
		if GameManager.roll_loot(imp_def):
			hits += 1
			dry = 0
		else:
			dry += 1
			longest_dry = maxi(longest_dry, dry)
	var beast_drops: int = 0
	for i in 10:
		beast_drops += 1 if GameManager.roll_loot(beast_def) else 0
	_check(beast_drops == 10, "every beast kill drops a shard")
	_check(hits >= 40 and hits <= 62, "100 imp kills drop %d shards (40-62)" % hits)
	_check(longest_dry < imp_def.drop_pity, "never more than %d imp kills in a row without a shard (%d)" % [imp_def.drop_pity - 1, longest_dry])
	GameManager.loot_misses = {}

	# The Moon Lantern by the tent.
	await _start_fresh_run()
	var lantern: MoonLantern = MoonLantern.find(get_tree())
	var player: Node3D = get_tree().get_first_node_in_group("player")
	_check(lantern != null and lantern.stage == 0 and lantern.max_stage() == 3 and lantern.radius() == 0.0,
		"the Moon Lantern stands dark by the tent (3 stages in Chapter 1)")
	player.global_position = lantern.global_position + Vector3(1.5, 0, 0)
	_check(not player.call("try_feed_lantern"), "nothing to hand over without shards")
	ResourceManager.add(&"glow_shards", 2)
	await get_tree().process_frame
	var card: StoryCard = _main.get_node("HUD").call("story_card")
	_check(card != null and String(card.lines()[0]["id"]) == "shard.leo", "the first shard of a run gets its story card")
	# Feature 046: a card still talking is never cut short, and dawn
	# cards carry a page of Mum's notebook.
	var hud: Node = _main.get_node("HUD")
	_check(hud.call("show_story", StoryLibrary.first(&"dawn", 1, 2), "") == null and hud.call("story_card") == card,
		"a dawn card waits while the shard card talks")
	card.dismiss()
	await get_tree().process_frame
	await get_tree().process_frame
	var dawn_card: StoryCard = hud.call("story_card")
	var note: Dictionary = dawn_card.lines().back() if dawn_card != null else {}
	_check(dawn_card != null and dawn_card != card and dawn_card.lines().size() == 3 and String(note.get("speaker", "")) == "note",
		"then it shows: Leo, Nela, and one of Mum's notes")
	_check(StoryLibrary.speaker_name("note") == "Mum's note"
		and StoryLibrary.speaker_portrait("note", String(note.get("face", ""))).resource_path.ends_with("mum_curious.png"),
		"the note shows as Mum's, with her face")
	_check(dawn_card != null and dawn_card.find_child("Sketch", true, false) is TextureRect,
		"and her sketch from the notebook")
	if dawn_card != null:
		dawn_card.dismiss()
	var beast_intro: MobDefinition = load("res://resources/mobs/bramble_beast.tres") as MobDefinition
	hud.call("_on_mob_spawned", player, beast_intro)
	_check(hud.call("banner_subtitle") == beast_intro.description and beast_intro.description != "",
		"the first Bramble Beast of a run says what it is")
	hud.call("_on_mob_spawned", player, beast_intro)
	_check(hud.call("banner_subtitle") == "", "the next one only warns")
	_check(player.call("try_feed_lantern") and lantern.stage == 1 and ResourceManager.get_count(&"glow_shards") == 0,
		"E by the lantern hands over the shards: stage 1")
	_check(is_equal_approx(lantern.radius(), lantern.min_radius), "stage 1 lights a %.1f m ring" % lantern.radius())
	var imp: Mob = _spawn_mob(imp_def, lantern.global_position + Vector3(2.5, 0, 0))
	imp.set_physics_process(false)
	await get_tree().process_frame
	_check(float(imp.call("_torch_slow_factor")) <= lantern.slow_factor, "an imp in the ring is slowed")
	var imp_hp: int = imp.current_hp
	await _wait(lantern.light_interval_seconds + 0.4)
	_check(imp.current_hp < imp_hp, "moonlight hurts the imp (%d -> %d)" % [imp_hp, imp.current_hp])
	imp.take_damage(999, player)
	ResourceManager.add(&"glow_shards", 10)
	var carried: int = ResourceManager.get_count(&"glow_shards")
	lantern.deliver(player)
	_check(lantern.is_full() and lantern.shards == lantern.shards_for_max()
		and ResourceManager.get_count(&"glow_shards") == carried - (lantern.shards_for_max() - 2),
		"the lantern takes only what it still needs (%d shards)" % lantern.shards)
	_check(is_equal_approx(lantern.radius(), lantern.max_radius), "fully lit: a %.1f m ring" % lantern.radius())
	var gremlin_def: MobDefinition = load("res://resources/mobs/mushroom_gremlin.tres") as MobDefinition
	var gremlin: Mob = _spawn_mob(gremlin_def, lantern.global_position + Vector3(6.0, 0, 0))
	await _wait(2.5)
	_check(not is_instance_valid(gremlin) or gremlin.is_fleeing and gremlin.loot_amount == 0, "a gremlin turns back at the bright ring")
	if is_instance_valid(gremlin):
		gremlin.take_damage(999, player)
	var data: Dictionary = SaveManager.snapshot()
	_check(int(data["lantern"]["shards"]) == lantern.shards, "the save holds the lantern's shards")
	var legacy: Dictionary = data.duplicate(true)
	legacy.erase("lantern")
	GameManager.set("_pending_save", SaveManager.parse(SaveManager.serialize(data)))
	await _start_fresh_run()
	lantern = MoonLantern.find(get_tree())
	_check(lantern.is_full(), "Continue keeps the lantern lit (stage %d)" % lantern.stage)
	GameManager.set("_pending_save", legacy)
	await _start_fresh_run()
	_check(MoonLantern.find(get_tree()).stage == 0, "older saves start the lantern dark")
	GameManager.nights_to_win = 7
	await _start_fresh_run()
	_check(MoonLantern.find(get_tree()).max_stage() == 6, "Chapter 2's lantern has 6 stages")
	GameManager.nights_to_win = 3

	# Feature 043: Mum's portraits, her walk home, and her seat at the title.
	_check(StoryLibrary.speaker_portrait("mum", "worried").resource_path.ends_with("mum_worried.png")
		and StoryLibrary.speaker_portrait("mum").resource_path.ends_with("mum.png")
		and StoryLibrary.speaker_portrait("mum", "nope").resource_path.ends_with("mum.png"), "Mum's expressions, with a fallback")
	# Feature 047: the team's paintings, the kids' faces, the lantern model.
	var painted: bool = true
	for trigger in [&"intro", &"win"]:
		for chapter in [1, 2]:
			for beat in StoryLibrary.find(trigger, chapter):
				painted = painted and (beat as StoryBeat).painting.resource_path.begins_with("res://assets/ui/story/story_")
	_check(painted, "every storybook page has its own painting")
	_check(StoryLibrary.speaker_portrait("nela", "worried").resource_path.ends_with("nela_worried.png")
		and StoryLibrary.speaker_portrait("leo", "proud").resource_path.ends_with("leo_proud.png")
		and StoryLibrary.speaker_portrait("leo", "nope") == HeroRoster.get_hero(&"leo").portrait,
		"the kids' painted faces, with a fallback to their portraits")
	var lantern_model: Node3D = MoonLantern.find(get_tree()).get_node_or_null("Visual") as Node3D
	_check(lantern_model != null and lantern_model.find_child("moon_lantern*", true, false) is MeshInstance3D,
		"the Moon Lantern is the team's model")
	var hero: Node3D = get_tree().get_first_node_in_group("player")
	get_tree().paused = true  # as behind the end screen
	var arrival: MumArrival = MumArrival.play(get_tree().current_scene, hero.global_position)
	await get_tree().process_frame
	var model: Node = arrival.visual.get_child(0) if arrival.visual.get_child_count() > 0 else null
	_check(model != null and model.find_child("AnimationPlayer", true, false) != null, "Mum's model loads, with its clips")
	var player_anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer if model != null else null
	_check(player_anim != null and player_anim.has_animation("Wave") and player_anim.has_animation("Walking_A"),
		"Mum can walk and wave")
	var gap: float = arrival.global_position.distance_to(arrival.target)
	await _wait(1.2)
	_check(arrival.global_position.distance_to(arrival.target) < gap - 0.5, "Mum walks to the kids while the world is paused")
	var arrived: Array = [false]
	arrival.finished.connect(func() -> void: arrived[0] = true)
	arrival.finish()
	_check(arrived[0] and arrival.global_position.distance_to(arrival.target) < 0.01, "skipping puts Mum by the kids")
	get_tree().paused = false
	var backdrop: GDScript = load("res://scripts/ui/title_backdrop.gd")
	_check(not backdrop.call("mum_is_home"), "Mum isn't home before the true ending")
	StoryLibrary.mark_seen(StoryLibrary.TRUE_ENDING)
	_check(backdrop.call("mum_is_home"), "after the true ending Mum sits by the title fire")
	var game_camera: Camera3D = get_viewport().get_camera_3d()
	var title: Node3D = backdrop.new()
	add_child(title)
	await get_tree().process_frame
	var title_golem: LittleGolem = title.get_node_or_null("LittleGolem") as LittleGolem
	_check(title_golem != null and title_golem.curled, "and the little golem curls up by it too")
	title.free()
	if game_camera != null:
		game_camera.make_current()
	StoryLibrary.forget_progress()


## Feature 017: repair, the new resources, recipes, traps and lanterns.
func _check_feature_017(player: Node3D, companion: Node3D, fence: Building) -> void:
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
	companion.call("set_task", 4)
	t = 0.0
	while fire.get_missing_hp() > 0 and t < 15.0:
		await _wait(0.25)
		t += 0.25
	_check(fire.get_missing_hp() == 0, "Nela repaired the campfire (%.1fs)" % t)
	companion.call("set_task", 0)

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
	player.call("_try_eat_berries")
	# A level-up earlier in the run may have dealt Berry Belly (ticket 03).
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
	await _check_feature_019(player, companion)
	await _check_mushroom_gremlin(player)


## Feature 019: stash caps, the Storage Crate, the Reinforced Wall and
## the Crafting Table recipes.
func _check_feature_019(player: Node3D, companion: Node3D) -> void:
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
		(other as SnapTrap).recharge()  # the 017 trap has used a snap
	_check(not CraftingManager.can_craft(refill), "trap refill needs a used trap")
	trap.current_hp = 1
	_check(CraftingManager.craft(refill, player) and trap.current_hp == 3, "trap refill restored all snaps")
	trap.queue_free()
	table.queue_free()
	await get_tree().process_frame


## Feature 021: Mushroom Gremlins steal from the stash and run; caught,
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
	# Feature 027: its own clips; it sneaks in and scurries off.
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


## Feature 044: an idle or gathering hero fights a mob that comes close,
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
	player.call("_begin_gather_on", bush)
	_check(int(player.get("_state")) == 2, "gathering a bush")
	imp = _spawn_mob(imp_def, player.global_position + Vector3(0, 0, 2.0))
	imp.set_physics_process(false)
	await _wait(0.5)
	_check(int(player.get("command")) == 2 and player.get("command_target") == imp, "a close imp interrupts the gather")
	imp.take_damage(999, player)
	t = 0.0
	while int(player.get("_state")) != 2 and t < 4.0:
		await _wait(0.1)
		t += 0.1
	_check(int(player.get("_state")) == 2 and player.get("_active_node") == bush, "then the hero goes back to the bush (%.1fs)" % t)
	player.call("_cancel_active_gather")
	player.set("auto_attack", false)


## Feature 044: a placed building is a blueprint that does nothing until
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
	var beat: BuildBeat = player.get("_build_beat") as BuildBeat
	var hits_before: int = beat.hits
	var t: float = 0.0
	var hammered: bool = false
	var hammer_out: bool = false
	var clip_rose: bool = false
	while crate.is_blueprint() and t < 15.0:
		await _wait(0.1)
		t += 0.1
		hammered = hammered or int(player.get("command")) == 6
		hammer_out = hammer_out or visual.tool_shown() == &"hammer"
		if ghost_material != null and crate.is_blueprint():
			clip_rose = clip_rose or float(ghost_material.get_shader_parameter("clip_y")) > clip_start + 0.2
	_check(hammered and crate.is_built(), "the idle hero walks over and builds it (%.1fs for %.0fs of work)" % [t, crate_def.build_seconds])
	_check(hammer_out and beat.hits > hits_before and clip_rose,
		"with a hammer in hand (%d blows landed), the solid part rising inside the ghost" % (beat.hits - hits_before))
	await _wait(0.6)
	_check(crate.get_node_or_null("Ghost") == null and crate.get_node_or_null("Site") == null and visual.tool_shown() == &""
		and crate.current_hp == crate_def.max_hp, "built: ghost and site gone, hammer away, full HP")
	_check(ResourceManager.get_cap(&"wood") > cap_before and ProgressionManager.get_xp(player) >= xp_before + BuildManager.BUILD_XP_REWARD,
		"then it works, and the build XP comes on completion")
	# The companion's Repair task builds too.
	player.global_position = Vector3(-14, 0, -14)
	player.set_physics_process(false)
	var fence: Building = BuildManager.place_blueprint(BuildManager.get_definition(&"wooden_fence"), Transform3D(Basis(), companion.global_position + Vector3(0, 0, 2.5)))
	companion.call("set_task", 4)
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
	companion.call("set_task", 0)
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


## Feature 044: told to guard from behind a long wall, the companion
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
	companion.call("set_task", 0)
	companion.global_position = fire.global_position + Vector3(0.3, 0, -9.0)
	await _wait(0.2)
	companion.call("set_task", 2)
	var t: float = 0.0
	var radius: float = float(companion.get("guard_radius"))
	while _flat(companion.global_position).distance_to(_flat(fire.global_position)) > radius + 0.3 and t < 12.0:
		await _wait(0.25)
		t += 0.25
	_check(t < 12.0, "guarding from behind a wall, the companion walks round it (%.1fs, %d hops)" % [t, int(companion.get("unstuck_count"))])
	companion.call("set_task", 0)
	wall.queue_free()
	await get_tree().process_frame
	nav.call("_request_bake")  # and without it
	await nav.baked


func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func _spawn_mob(definition: MobDefinition, position: Vector3) -> Mob:
	var mob: Mob = definition.get_scene().instantiate() as Mob
	get_tree().current_scene.add_child(mob)
	mob.global_position = position
	return mob


func _spawn_building(id: StringName, position: Vector3) -> Building:
	var building: Building = BuildManager.get_definition(id).get_scene().instantiate() as Building
	get_tree().current_scene.add_child(building)
	building.global_position = position
	return building


## Feature 018: waves mix in Bramble Beasts, which go for buildings.
func _check_bramble_beast(player: Node3D) -> void:
	var spawner: Node = get_tree().get_first_node_in_group("mob_spawner")
	# Feature 028: the Shadow Imp has its own clips.
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

	# Feature 026: its own clips, and a telegraphed slam.
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
	await _wait(beast_def.attack_hit_delay * 0.5)
	_check(fence.current_hp == before, "the slam has not landed during the windup")
	await _wait(beast_def.attack_hit_delay * 0.5 + 0.25)
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


## Feature 023: actions layer over locomotion. While Leo runs, a swing
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
	await get_tree().physics_frame  # the tree updates on physics frames
	await get_tree().physics_frame
	_check(visual.active_action_layer() == "upper", "a swing while running plays on the upper body")
	player.stop_commands()
	await _wait(0.8)
	visual.play_action(&"attack", 1.9)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not visual.is_moving() and visual.active_action_layer() == "full", "a swing standing still plays on the whole body")
	await _wait(0.6)

	# Feature 024: footsteps, swaying foliage, day ambience.
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


func _recipe(id: StringName) -> CraftingRecipe:
	for recipe in CraftingManager.get_recipes():
		if recipe.id == id:
			return recipe
	return null


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


## Feature 020: Continue rebuilds the camp from the night-1 autosave,
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

	GameManager.nights_to_win = int(data["nights_to_win"])
	GameManager.set("_pending_save", data)
	await _start_fresh_run()
	_check(TimeManager.day_number == 2 and TimeManager.current_phase == TimeManager.Phase.DAY, "continued at the morning of day 2")
	_check(ResourceManager.get_count(&"wood") == int(data["inventory"].get("wood", 0)), "inventory restored")
	var buildings: int = get_tree().get_nodes_in_group(Building.BUILDINGS_GROUP).size()
	_check(buildings == (data["buildings"] as Array).size(), "buildings restored (%d)" % buildings)
	var fire: BaseCore = _campfire()
	_check(fire.has_hearth == bool(data["campfire"]["hearth"]) and fire.current_hp == int(data["campfire"]["hp"]),
		"campfire restored (%d HP, hearth %s)" % [fire.current_hp, fire.has_hearth])
	var player: Node = get_tree().get_first_node_in_group("player")
	_check(ProgressionManager.get_xp(player) == int(data["player"]["xp"]) and bool(player.get("has_signature")) == bool(data["player"]["signature"]),
		"Leo's progress restored (level %d)" % ProgressionManager.get_level(player))
	_check(int(GameManager.stats[&"nights_survived"]) == 1, "stats restored (1 night survived)")

	# A 7-night run.
	GameManager.nights_to_win = 7
	await _start_fresh_run()
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud == null:
		hud = _main.get_node_or_null("HUD")
	_check(hud != null and (hud.get("_moons") as Array).size() == 7, "7-night run shows 7 moons")
	var spawner: Node = get_tree().get_first_node_in_group("mob_spawner")
	_check(spawner.get_wave_size(7) == 19 and spawner.get_heavy_count(7) == 6, "night 7: 19 imps and 6 beasts")
	GameManager.nights_to_win = 3


## Feature 034: the hero select screen, and a run playing Nela. Each
## hero keeps their style in either role and their signature craft.
func _run_hero_scenario() -> void:
	print("smoke: --- hero scenario ---")
	var screen: Node = (load("res://scenes/ui/HeroSelect.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	_check(int(screen.get("selected")) == 0 and (screen.call("selected_hero") as HeroDefinition).id == &"leo",
		"hero select opens on the last pick (Leo)")
	screen.call("select", 1)
	_check((screen.call("selected_hero") as HeroDefinition).id == &"nela", "hero select picks Nela")
	screen.call("select", HeroRoster.all().size())
	_check(int(screen.get("selected")) == 0, "hero select wraps around the roster")
	screen.queue_free()
	await get_tree().process_frame

	GameManager.set_party(&"nela")
	_check(GameManager.companion_id == &"leo", "Leo comes along when Nela is played")
	await _start_fresh_run()
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var companion: Node3D = get_tree().get_first_node_in_group("companions")
	_check(player.is_in_group(HeroRoster.group_for(&"nela")) and companion.is_in_group(HeroRoster.group_for(&"leo")),
		"the player is Nela and the companion is Leo")
	var nela: HeroDefinition = HeroRoster.get_hero(&"nela")
	var visual: CharacterVisual = player.get_node("Visual") as CharacterVisual
	_check(visual.model_scene == nela.model_scene and int(player.get("max_hp")) == nela.stats.base_max_health,
		"the player has Nela's body and health (%d HP)" % int(player.get("max_hp")))
	_check(float(player.get("attack_range")) > 4.0 and float(companion.call("get_attack_range")) <= 2.0,
		"Nela shoots from range; Leo fights up close")
	var hud: Node = _main.get_node_or_null("HUD")
	var portrait: HudWidgets.Portrait = hud.get("_hero_portrait") if hud != null else null
	_check(portrait != null and portrait.texture == nela.portrait, "the HUD shows Nela in the hero bar")

	# A pebble flies and hits an imp a few metres away.
	var spawner: Node = get_tree().get_first_node_in_group("mob_spawner")
	var imp: Mob = _spawn_mob(spawner.get("mob_definition"), player.global_position + Vector3(3.5, 0, 0))
	await get_tree().process_frame
	var imp_hp: int = imp.current_hp
	player.call("_perform_attack", imp)
	_check(imp.current_hp == imp_hp, "the pebble has not landed yet")
	await _wait(PebbleShot.FLIGHT_SECONDS + 0.2)
	_check(not is_instance_valid(imp) or imp.current_hp < imp_hp, "Nela's pebble hit the imp 3.5 m away")
	if is_instance_valid(imp):
		imp.take_damage(999, player)

	# The signature crafts follow the hero, not the role.
	for item in [&"wood", &"scrap"]:
		ResourceManager.add(item, 10)
	var table: Building = _spawn_building(&"crafting_table", Vector3(5, 0, -6))
	var reach: float = float(player.get("attack_range"))
	_check(CraftingManager.craft(_recipe(&"slingshot"), player)
		and is_equal_approx(float(player.get("attack_range")), reach * nela.signature_range_factor), "the slingshot goes to Nela (the player)")
	var damage: int = int(companion.get("_current_attack_damage"))
	_check(CraftingManager.craft(_recipe(&"sturdy_stick"), player)
		and int(companion.get("_current_attack_damage")) == damage + 2, "the sturdy stick goes to Leo (the companion)")

	# The save remembers the party; Continue plays Nela again.
	var data: Dictionary = SaveManager.snapshot()
	_check(String(data["party"]["hero"]) == "nela" and String(data["party"]["companion"]) == "leo", "the save holds the party")
	var legacy: Dictionary = data.duplicate(true)
	legacy.erase("party")
	_check(SaveManager.party_of(legacy)["hero"] == &"leo", "older saves without a party are Leo with Nela")
	table.queue_free()
	GameManager.set_party(&"leo")
	var party: Dictionary = SaveManager.party_of(SaveManager.parse(SaveManager.serialize(data)))
	GameManager.set_party(party["hero"], party["companion"])
	GameManager.set("_pending_save", data)
	await _start_fresh_run()
	player = get_tree().get_first_node_in_group("player")
	_check(player.is_in_group(HeroRoster.group_for(&"nela")) and bool(player.get("has_signature")),
		"continued as Nela, slingshot and all")
	GameManager.set_party(&"leo")


## Feature 037: the siblings' barks. The right hero speaks, keyed by who
## is played; cooldowns hold back spam; a bark never cuts off a story
## voice; the companion warns about a mob behind the player.
func _run_bark_scenario() -> void:
	print("smoke: --- bark scenario ---")
	GameManager.set_party(&"leo")
	await _start_fresh_run()
	var director: BarkDirector = get_tree().get_first_node_in_group("bark_director") as BarkDirector
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var companion: Node3D = get_tree().get_first_node_in_group("companions")
	_check(director != null, "the run has a bark director")
	var max_hp: int = int(companion.get("max_hp"))
	companion.call("take_damage", max_hp - int(max_hp * 0.2))
	var bubble: SpeechBubble = SpeechBubble.on(companion)
	_check(bubble != null and _bark_line(bubble.text, &"low_hp", &"nela"), "Nela at low HP says so over her head")
	_check(SpeechBubble.on(player) == null, "the player stays quiet")
	_check(not director.bark(&"low_hp", companion), "low HP again within its cooldown: no bark")
	_check(not director.bark(&"thief"), "a second bark right away waits for the shared cooldown")
	director.clock += BarkDirector.GLOBAL_COOLDOWN + 1.0
	_check(director.bark(&"thief"), "a gremlin steals: the siblings shout")
	_check(_bark_line(SpeechBubble.on(player).text, &"thief", &"leo"), "Leo (played) calls out first")
	await _wait(BarkDirector.REPLY_DELAY + 1.0)
	_check(SpeechBubble.on(companion) != null and _bark_line(SpeechBubble.on(companion).text, &"thief", &"nela"),
		"Nela replies")
	_check(SpeechBubble.on(companion).position.y > float(companion.get("_hp_bar").position.y),
		"the bubble sits above the health bar")
	# Feature 046: a gremlin that gets away, and the first beast once a run.
	director.clock += BarkDirector.GLOBAL_COOLDOWN + 1.0
	var runaway: Mob = _spawn_mob(load("res://resources/mobs/mushroom_gremlin.tres") as MobDefinition,
		player.global_position + Vector3(0, 0, 14))
	await get_tree().process_frame
	runaway.escaped.emit(runaway, &"wood", 2)
	_check(SpeechBubble.on(player) != null and _bark_line(SpeechBubble.on(player).text, &"thief_escaped", &"leo"),
		"a gremlin gets away: Leo says where it went")
	runaway.queue_free()
	director.clock += BarkDirector.GLOBAL_COOLDOWN + 1.0
	_check(director.bark(&"first_beast"), "the first Bramble Beast of a run gets a shout")
	director.clock += BarkDirector.GLOBAL_COOLDOWN + 1.0
	_check(not director.bark(&"first_beast"), "later beasts in the run do not")

	# A story line keeps speaking under a bark.
	var story_voice: AudioStream = load("res://assets/audio/sfx/chirp_nela_1.ogg")
	AudioManager.play_voice(story_voice)
	ProgressionManager.level_up.emit(player, 2)
	_check(_bark_line(SpeechBubble.on(player).text, &"level_up", &"leo"), "a level-up is cheered by that hero")
	_check(AudioManager.play_bark(null, "leo") == 0.0, "no bark audio while a story line speaks")
	AudioManager.stop_voice()
	_check(AudioManager.play_bark(null, "leo") > 0.0, "the bark chirps when the story is quiet")

	# Danger behind the player: the companion warns.
	director.clock += 30.0
	var imp_def: MobDefinition = get_tree().get_first_node_in_group("mob_spawner").get("mob_definition")
	var facing: Vector3 = player.call("get_facing")
	var imp: Mob = _spawn_mob(imp_def, player.global_position - facing * 3.0)
	await get_tree().process_frame
	_check(director.danger_behind(), "an imp 3 m behind the player counts as danger")
	await _wait(BarkDirector.DANGER_POLL_SECONDS + 0.3)
	_check(SpeechBubble.on(companion) != null and _bark_line(SpeechBubble.on(companion).text, &"danger_behind", &"nela"),
		"Nela warns: behind you!")
	director.clock += 30.0
	companion.call("take_damage", 9999)
	_check(_bark_line(SpeechBubble.on(player).text, &"companion_down", &"leo"), "Leo calls out when Nela is knocked out")
	director.clock += 30.0
	_check(not director.bark(&"danger_behind"), "a knocked-out companion gives no warnings")
	imp.take_damage(999, player)

	# Nela played: the speakers swap, and the events reach the director.
	GameManager.set_party(&"nela")
	await _start_fresh_run()
	director = get_tree().get_first_node_in_group("bark_director") as BarkDirector
	player = get_tree().get_first_node_in_group("player")
	companion = get_tree().get_first_node_in_group("companions")
	var gremlin_def: MobDefinition = load("res://resources/mobs/mushroom_gremlin.tres")
	var gremlin: Mob = _spawn_mob(gremlin_def, player.global_position + Vector3(8, 0, 8))
	await get_tree().process_frame
	# Keep the scene quiet and the gremlin put: a story card (the first
	# gremlin's beat) holds barks back, and a gremlin left to roam can be
	# caught or escape (and be freed) before the reply.
	await _close_story()
	gremlin.stun(30.0)
	gremlin.stole.emit(gremlin, &"wood", 2)
	_check(SpeechBubble.on(player) != null and _bark_line(SpeechBubble.on(player).text, &"thief", &"nela"),
		"Nela played: she shouts at the thief first")
	await _wait(BarkDirector.REPLY_DELAY + 1.0)
	_check(SpeechBubble.on(companion) != null and _bark_line(SpeechBubble.on(companion).text, &"thief", &"leo"),
		"and Leo replies")
	if is_instance_valid(gremlin):
		gremlin.take_damage(999, player)
	director.clock += 30.0
	var beast: Mob = _spawn_mob(load("res://resources/mobs/bramble_beast.tres"), player.global_position + Vector3(10, 0, -8))
	await get_tree().process_frame
	_check(_bark_line(SpeechBubble.on(player).text, &"first_beast", &"nela"), "the first beast of the night gets a shout")
	director.clock += 30.0
	_check(not director.bark(&"first_beast"), "only once a night")
	beast.take_damage(9999, player)
	GameManager.set_party(&"leo")


## Feature 038: the Moon-Eater. Its eyes watch on night 5; on night 7 it
## rises with a boss bar and holds the night; its stomp can be dodged;
## summons respect the mob cap and put out torches; scripted damage
## takes it through every phase, including a reach that runs out of
## time; calmed, it shrinks by the fire and the true ending plays.
func _run_boss_scenario() -> void:
	print("smoke: --- boss scenario ---")
	GameManager.set_party(&"leo")
	GameManager.nights_to_win = 7
	await _start_fresh_run()
	var spawner: MobSpawner = get_tree().get_first_node_in_group("mob_spawner") as MobSpawner
	_check(spawner.is_boss_night(7) and not spawner.is_boss_night(6), "the Moon-Eater comes on Chapter 2's last night")
	var wave: Array[MobDefinition] = spawner.build_wave(7)
	_check(wave[0].is_boss and wave.size() == 1 + spawner.boss_escort, "night 7 is the boss and %d imps" % spawner.boss_escort)
	GameManager.nights_to_win = 3
	_check(not spawner.is_boss_night(3), "no boss in Chapter 1")
	GameManager.nights_to_win = 7

	# Night 5: its eyes at the treeline, gone at dawn.
	TimeManager.day_number = 5
	while not TimeManager.is_night():
		TimeManager.skip_phase()
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("moon_eater_eyes").size() == 1, "night 5: its eyes watch from the treeline")
	TimeManager.skip_phase()
	await _wait(2.0)
	_check(get_tree().get_nodes_in_group("moon_eater_eyes").is_empty(), "the eyes fade at dawn")

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
		GameManager.nights_to_win = 3
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
	var mums: Array = get_tree().get_nodes_in_group("mum")  # the story scenario left one too
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
	GameManager.nights_to_win = 3


## Perk cards 01: a level-up opens the picker, a pick applies its
## effect (Quick Hands: a shorter gather), the auto-pick fires after the
## timeout, and the game returns to normal speed each time.
func _run_perk_01_scenario() -> void:
	print("smoke: --- perk 01 scenario ---")
	await _start_fresh_run()
	PerkManager.auto_pick_seconds = 5.0
	var player: Node = get_tree().get_first_node_in_group("player")
	var tree_node: ResourceNode = _find_resource_node(&"wood")
	var base_seconds: float = tree_node.gather_seconds_for(player)
	_check(is_equal_approx(base_seconds, tree_node.gather_time_seconds) and PerkManager.perks_of(player).is_empty(),
		"no perks at run start (gather %.1f s)" % base_seconds)

	# More cards than fit in a deal: seed one that has Quick Hands in it.
	for deal_seed in range(256):
		PerkManager.rng.seed = deal_seed
		if PerkManager.offer(player).any(func(p: PerkDefinition) -> bool: return p.id == &"quick_hands"):
			PerkManager.rng.seed = deal_seed
			break
	ProgressionManager.award_xp(player, ProgressionManager.get_xp_to_next_level(player), &"test")
	var picker: PerkPicker = PerkManager.picker()
	_check(ProgressionManager.get_level(player) == 2 and picker != null, "reaching level 2 opens the perk picker")
	if picker == null:
		return
	var ids: Array = picker.cards().map(func(p: PerkDefinition) -> StringName: return p.id)
	var distinct: Dictionary = {}
	for id in ids:
		distinct[id] = true
	_check(ids.size() == mini(3, PerkManager.definitions().size()) and distinct.size() == ids.size()
		and picker.card_buttons().size() == ids.size(), "the picker deals distinct cards (%s)" % ", ".join(ids))
	_check(is_equal_approx(Engine.time_scale, SPEED * PerkPicker.SLOW_FACTOR), "the game runs at 10% speed while picking")
	var index: int = ids.find(&"quick_hands")
	_check(index >= 0, "Quick Hands is on offer")
	# Press its number key, as a player would.
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_1 + index
	key.keycode = KEY_1 + index
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(PerkManager.has(player, &"quick_hands") and not PerkManager.is_picking(), "pressing %d takes Quick Hands" % (index + 1))
	_check(is_equal_approx(Engine.time_scale, SPEED), "normal speed once a card is picked")
	_check(is_equal_approx(tree_node.gather_seconds_for(player), base_seconds * 0.7), "Quick Hands: gathering takes 30% less time")
	# The gather itself runs the shorter time (on a node nobody is using).
	var started: bool = false
	for node in get_tree().current_scene.find_children("*", "ResourceNode", true, false):
		var gather_node: ResourceNode = node as ResourceNode
		if gather_node.begin_gather(player):
			var timer: Timer = gather_node.get("_gather_timer")
			started = is_equal_approx(timer.wait_time, gather_node.gather_time_seconds * 0.7)
			gather_node.cancel_gather(player)
			break
	_check(started, "the gather timer runs the shorter time")

	# The pool is used up (Quick Hands does not stack): no picker.
	if PerkManager.offer(player).is_empty():
		ProgressionManager.award_xp(player, ProgressionManager.get_xp_to_next_level(player), &"test")
		_check(ProgressionManager.get_level(player) == 3 and not PerkManager.is_picking(), "an empty pool skips the picker")

	# A new run: level-ups replayed from a save never open the picker.
	await _start_fresh_run()
	PerkManager.auto_pick_seconds = 0.5
	player = get_tree().get_first_node_in_group("player")
	_check(PerkManager.perks_of(player).is_empty(), "a new run starts with no perks")
	var stats: CharacterStatsDefinition = ProgressionManager.get_stats(player)
	ProgressionManager.restore_xp(player, stats.xp_threshold_for_level(2))
	_check(ProgressionManager.get_level(player) == 2 and not PerkManager.is_picking(), "levelling up while restoring a save opens no picker")

	# Nobody picks: the first card is taken after the timeout, through a hit-stop.
	ProgressionManager.award_xp(player, ProgressionManager.get_xp_to_next_level(player), &"test")
	picker = PerkManager.picker()
	_check(picker != null, "the next level-up opens the picker")
	if picker == null:
		return
	var first: StringName = picker.cards()[0].id
	Fx.hit_stop(0.05)
	await get_tree().create_timer(0.2, true, false, true).timeout
	_check(PerkManager.is_picking(), "the picker waits before it auto-picks")
	await get_tree().create_timer(0.6, true, false, true).timeout
	_check(PerkManager.has(player, first) and not PerkManager.is_picking(), "the auto-pick takes the first card (%s)" % first)
	_check(is_equal_approx(Engine.time_scale, SPEED), "normal speed after the auto-pick (%.2f)" % Engine.time_scale)


## Perk cards 04: each hero is dealt their own cards and never the other
## hero's, and Big Swing, Stand Firm, Ricochet and Eagle Eye work whether
## the hero is played or tags along as the companion.
func _run_perk_04_scenario() -> void:
	print("smoke: --- perk 04 scenario ---")
	for hero_id in [&"leo", &"nela"]:
		GameManager.set_party(hero_id)
		await _start_fresh_run()
		var player: Node3D = get_tree().get_first_node_in_group("player")
		var companion: Node3D = get_tree().get_first_node_in_group("companions")
		# Hold the companion still (the test swings for it), and stop the
		# watch post shooting the staged mobs.
		companion.set_physics_process(false)
		for building in get_tree().current_scene.find_children("*", "Building", true, false):
			building.set_physics_process(false)
		for who in [player, companion]:
			var own: StringName = (who.get("hero") as HeroDefinition).id
			var other: StringName = &"nela" if own == &"leo" else &"leo"
			var dealt_own: bool = true
			var dealt_other: bool = false
			for i in 20:
				var pools: Array = PerkManager.offer(who, 99).map(func(p: PerkDefinition) -> StringName: return p.pool)
				dealt_own = dealt_own and pools.count(own) >= 2
				dealt_other = dealt_other or pools.has(other)
			_check(dealt_own and not dealt_other, "%s is dealt their own cards and never %s's" % [own, other])
		for who in [player, companion]:
			if (who.get("hero") as HeroDefinition).id == &"leo":
				await _check_perk_04_leo(who)
			else:
				await _check_perk_04_nela(who)
	GameManager.set_party(&"leo")


func _check_perk_04_leo(leo: Node3D) -> void:
	var role: String = "player" if leo.is_in_group("player") else "companion"
	var fire: Node3D = _campfire()
	var spot: Vector3 = fire.global_position + Vector3(9, 0, 0)
	leo.global_position = spot
	var beast_def: MobDefinition = load("res://resources/mobs/bramble_beast.tres") as MobDefinition
	var first: Mob = _spawn_mob(beast_def, spot + Vector3(1.5, 0, 0))
	var second: Mob = _spawn_mob(beast_def, spot + Vector3(1.5, 0, 1.5))
	first.set_physics_process(false)
	second.set_physics_process(false)
	await get_tree().process_frame
	# Big Swing: one swing, two mobs.
	await _perk_04_swing(leo, first)
	_check(first.current_hp < beast_def.max_hp and second.current_hp == beast_def.max_hp, "%s Leo: a swing hits one mob" % role)
	var hp: Array[int] = [first.current_hp, second.current_hp]
	PerkManager.take(leo, &"big_swing")
	await _perk_04_swing(leo, first)
	_check(first.current_hp < hp[0] and second.current_hp < hp[1], "%s Leo, Big Swing: a swing hits two mobs" % role)
	await _perk_04_clear_mobs()

	# Stand Firm: 25% less damage near the fire, none away from it.
	PerkManager.take(leo, &"stand_firm")
	var taken: Array[int] = []
	for offset in [Vector3(2.5, 0, 0), Vector3(9, 0, 0)]:
		leo.global_position = fire.global_position + offset
		(leo as Hero).clear_invulnerability()
		var before: int = int(leo.get("current_hp"))
		leo.call("take_damage", 8, null)
		taken.append(before - int(leo.get("current_hp")))
	_check(taken == [6, 8], "%s Leo, Stand Firm: 8 damage is 6 near the fire, 8 away (%s)" % [role, taken])
	leo.set("current_hp", int(leo.get("max_hp")))
	(leo as Hero).clear_invulnerability()


func _check_perk_04_nela(nela: Node3D) -> void:
	var role: String = "player" if nela.is_in_group("player") else "companion"
	var spot: Vector3 = _campfire().global_position + Vector3(9, 0, 0)
	nela.global_position = spot
	var beast_def: MobDefinition = load("res://resources/mobs/bramble_beast.tres") as MobDefinition
	var first: Mob = _spawn_mob(beast_def, spot + Vector3(1.5, 0, 0))
	var second: Mob = _spawn_mob(beast_def, spot + Vector3(1.5, 0, 2.5))
	first.set_physics_process(false)
	second.set_physics_process(false)
	await get_tree().process_frame
	# Ricochet: the pebble bounces on to a second mob.
	await _perk_04_swing(nela, first)
	_check(first.current_hp < beast_def.max_hp and second.current_hp == beast_def.max_hp, "%s Nela: a pebble hits one mob" % role)
	var hp: Array[int] = [first.current_hp, second.current_hp]
	PerkManager.take(nela, &"ricochet")
	await _perk_04_swing(nela, first)
	_check(first.current_hp < hp[0] and second.current_hp < hp[1], "%s Nela, Ricochet: the pebble bounces to a second mob" % role)
	await _perk_04_clear_mobs()

	# Eagle Eye: 20% more reach, for the attack and for finding a target.
	var reach: float = float(nela.call("get_attack_range"))
	# The player looks a little past her reach (x1.2), the companion at it.
	var past: float = 1.3 if nela.is_in_group("player") else 1.1
	var far: Mob = _spawn_mob(beast_def, spot + Vector3(reach * past, 0, 0))
	far.set_physics_process(false)
	await get_tree().process_frame
	var found_before: bool = _perk_04_finds(nela, far, reach)
	PerkManager.take(nela, &"eagle_eye")
	var longer: float = float(nela.call("get_attack_range"))
	_check(is_equal_approx(longer, reach * 1.2), "%s Nela, Eagle Eye: reach %.2f -> %.2f m" % [role, reach, longer])
	_check(not found_before and _perk_04_finds(nela, far, longer), "%s Nela, Eagle Eye: targets a mob past her old reach" % role)
	if nela.is_in_group("player"):
		_check(is_equal_approx(float(nela.call("auto_attack_radius")), maxf(longer * 1.3, 3.5)), "player Nela, Eagle Eye: auto-attack reaches further")
	await _perk_04_clear_mobs()


## One attack from `hero` on `mob`, through its controller, then waits
## for the swing or the pebble (and any bounce) to land.
func _perk_04_swing(hero: Node3D, mob: Mob) -> void:
	if hero.is_in_group("player"):
		hero.call("_perform_attack", mob)
	else:
		hero.call("_attack_mob", mob)
	await _wait(1.2)


## Removes the staged mobs without a kill, so no XP (and no level-up
## card) comes of it.
func _perk_04_clear_mobs() -> void:
	for node in get_tree().get_nodes_in_group("mobs"):
		node.remove_from_group("mobs")
		node.queue_free()
	await get_tree().process_frame


## True if `hero` would pick `mob` as a target at its current reach.
func _perk_04_finds(hero: Node3D, mob: Mob, reach: float) -> bool:
	if hero.is_in_group("player"):
		return hero.call("_find_nearest_mob_in_range") == mob
	return hero.call("_find_nearest_mob", reach) == mob
## Perk cards 06: the companion takes a random card by itself, with a
## toast, never the picker; its own pool's rules hold.
func _run_perk_06_scenario() -> void:
	print("smoke: --- perk 06 scenario ---")
	await _start_fresh_run()
	PerkManager.auto_pick_seconds = 5.0  # the player's level-up would open a picker
	PerkManager.rng.seed = 6
	var hud: Node = get_tree().get_first_node_in_group("hud")
	var companion: Node = get_tree().get_first_node_in_group("companions")
	var hero: HeroDefinition = companion.get("hero") as HeroDefinition
	ProgressionManager.award_xp(companion, ProgressionManager.get_xp_to_next_level(companion), &"test")
	var taken: Array[StringName] = PerkManager.perks_of(companion)
	_check(ProgressionManager.get_level(companion) == 2 and taken.size() == 1 and not PerkManager.is_picking(),
		"a companion level-up takes a card by itself, no picker (%s)" % ", ".join(taken))
	if taken.is_empty():
		return
	var perk: PerkDefinition = PerkManager.get_definition(taken[0])
	var toasts: Array = hud.call("toasts")
	var line: String = "%s took %s!" % [hero.display_name, perk.display_name]
	_check(toasts.size() == 1 and (toasts[0] as HudToast).text() == line, "a toast says \"%s\"" % line)
	await get_tree().process_frame
	await get_tree().process_frame
	if not toasts.is_empty():
		var toast_rect: Rect2 = (toasts[0] as HudToast).get_global_rect()
		var banner_rect: Rect2 = (hud.get("_banner_plate") as Control).get_global_rect()
		var story_rect: Rect2 = (hud.get("_story_host") as Control).get_global_rect().grow_individual(0, 0, 430, 300)
		_check(not toast_rect.intersects(banner_rect) and not toast_rect.intersects(story_rect)
			and toast_rect.end.x <= 1280.0 and toast_rect.position.y > 60.0,
			"the toast sits on the right under the tray, clear of the banner and story card (%s)" % toast_rect)

	# Same pool rules as the picker: its own hero's cards, no repeats
	# unless the card stacks, nothing once the pool is used up.
	for i in PerkManager.definitions().size() + 1:
		ProgressionManager.award_xp(companion, ProgressionManager.get_xp_to_next_level(companion), &"test")
	taken = PerkManager.perks_of(companion)
	var fair: bool = not PerkManager.is_picking()
	for id in taken:
		var card: PerkDefinition = PerkManager.get_definition(id)
		fair = fair and card.is_for(hero.id, true) and (card.stacks or taken.count(id) == 1)
	var own: int = 0
	var any_stacks: bool = false
	for card in PerkManager.definitions():
		if card.is_for(hero.id, true):
			own += 1
			any_stacks = any_stacks or card.stacks
	_check(fair and (any_stacks or (taken.size() == own and PerkManager.offer(companion).is_empty())),
		"the companion's cards follow the pool rules: own hero's, never player-only, no repeats, stops when used up (%s)" % ", ".join(taken))
	var player: Node = get_tree().get_first_node_in_group("player")
	_check(PerkManager.perks_of(player).is_empty(), "the companion's cards are not the player's")

	# The toast fades by itself, in real time.
	await get_tree().create_timer(HudToast.POP_SECONDS + HudToast.SECONDS + HudToast.FADE_SECONDS + 0.3, true, false, true).timeout
	_check((hud.call("toasts") as Array).is_empty() and (hud.get("_toast_stack") as Node).get_child_count() == 0, "the toast fades and frees itself")

	# Level-ups replayed from a save take no card and show no toast.
	await _start_fresh_run()
	hud = get_tree().get_first_node_in_group("hud")
	companion = get_tree().get_first_node_in_group("companions")
	var stats: CharacterStatsDefinition = ProgressionManager.get_stats(companion)
	ProgressionManager.restore_xp(companion, stats.xp_threshold_for_level(3))
	_check(ProgressionManager.get_level(companion) == 3 and PerkManager.perks_of(companion).is_empty()
		and (hud.call("toasts") as Array).is_empty(), "a companion level-up while restoring a save takes no card")


## Ticket 02: the perks both heroes hold survive save and Continue, quietly
## (no picker), and a save from before perks loads with none.
func _run_perk_02_scenario() -> void:
	print("smoke: --- perk 02 scenario ---")
	await _start_fresh_run()
	var player: Node = get_tree().get_first_node_in_group("player")
	var sibling: Node = get_tree().get_first_node_in_group("companions")
	ProgressionManager.award_xp(player, ProgressionManager.get_xp_to_next_level(player), &"test")
	PerkManager.restore(player, [])  # forget the auto-picked card; take a known one
	PerkManager.take(player, &"quick_hands")
	PerkManager.take(sibling, &"quick_hands")
	var data: Dictionary = SaveManager.snapshot()
	_check(data["player"].get("perks", []) == ["quick_hands"] and data["sibling"].get("perks", []) == ["quick_hands"],
		"the save lists each hero's perks")
	GameManager.set("_pending_save", SaveManager.parse(SaveManager.serialize(data)))
	await _start_fresh_run()
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	sibling = get_tree().get_first_node_in_group("companions")
	var tree_node: ResourceNode = _find_resource_node(&"wood")
	_check(PerkManager.perks_of(player) == [&"quick_hands"] and PerkManager.perks_of(sibling) == [&"quick_hands"]
		and not PerkManager.is_picking(), "Continue restores both heroes' perks without the picker")
	_check(is_equal_approx(tree_node.gather_seconds_for(player), tree_node.gather_time_seconds * 0.7),
		"a restored Quick Hands still speeds up gathering")

	# A save from before perks: no "perks" keys at all.
	data = SaveManager.snapshot()
	(data["player"] as Dictionary).erase("perks")
	(data["sibling"] as Dictionary).erase("perks")
	GameManager.set("_pending_save", SaveManager.parse(SaveManager.serialize(data)))
	await _start_fresh_run()
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	sibling = get_tree().get_first_node_in_group("companions")
	_check(GameManager.is_playing() and PerkManager.perks_of(player).is_empty() and PerkManager.perks_of(sibling).is_empty()
		and not PerkManager.is_picking(), "a save from before perks loads with no perks")


## Perk cards 03: Ember Heart (torch life and radius), Berry Belly (snack
## healing) and Builder's Knack (Wood cost, in the build menu too).
func _run_perk_03_scenario() -> void:
	print("smoke: --- perk 03 scenario ---")
	await _start_fresh_run()
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	for id in [&"ember_heart", &"berry_belly", &"builders_knack"]:
		var perk: PerkDefinition = PerkManager.get_definition(id)
		_check(perk != null and perk.pool == &"shared" and not PerkManager.has(player, id), "%s is a shared card, not yet held" % id)

	# Ember Heart: a torch planted after it burns one more dawn, wider.
	ResourceManager.add(&"torch", 2)
	var plain: Node3D = _plant_torch(player)
	_check(PerkManager.take(player, &"ember_heart"), "took Ember Heart")
	var ember: Node3D = _plant_torch(player)
	if plain == null or ember == null:
		_check(false, "planted two torches")
		return
	var factor: float = PerkManager.get_definition(&"ember_heart").value
	var base_radius: float = float(plain.get("radius"))
	var plain_fire: Node = plain.get_node("Fire")
	var ember_fire: Node = ember.get_node("Fire")
	var ember_light: OmniLight3D = ember_fire.get("_light") as OmniLight3D
	_check(is_equal_approx(float(ember.get("radius")), base_radius * factor),
		"Ember Heart: torch radius %.1f -> %.1f m" % [base_radius, float(ember.get("radius"))])
	_check(is_equal_approx((ember.get_node("Radius") as Node3D).scale.x, factor * (plain.get_node("Radius") as Node3D).scale.x),
		"Ember Heart: the torch's ring grows with the radius")
	_check(is_equal_approx(float(ember_fire.get("light_range")), float(plain_fire.get("light_range")) * factor)
		and ember_light != null and is_equal_approx(ember_light.omni_range, float(ember_fire.get("light_range"))),
		"Ember Heart: the torch's light reaches %.1f m" % float(ember_fire.get("light_range")))
	var past_edge: Vector3 = Vector3(base_radius + 0.5, 0, 0)
	_check(ember.call("affects", ember.global_position + past_edge) and not plain.call("affects", plain.global_position + past_edge),
		"Ember Heart: the torch reaches imps past the old radius")
	plain.call("_on_dawn_started", TimeManager.day_number + 1)
	ember.call("_on_dawn_started", TimeManager.day_number + 1)
	_check(not plain.call("affects", plain.global_position) and ember.call("affects", ember.global_position),
		"Ember Heart: the torch outlasts the first dawn")
	ember.call("_on_dawn_started", TimeManager.day_number + 2)
	_check(not ember.call("affects", ember.global_position), "Ember Heart: the torch goes out at the second dawn")

	# Berry Belly: a Berry Snack heals 50% more.
	player.set("max_hp", 500)
	player.set("current_hp", 100)
	ResourceManager.add(&"snack", 2)
	player.call("_try_eat_berries")
	var plain_heal: int = int(player.get("current_hp")) - 100
	_check(PerkManager.take(player, &"berry_belly"), "took Berry Belly")
	player.set("current_hp", 100)
	player.call("_try_eat_berries")
	var belly_heal: int = int(player.get("current_hp")) - 100
	_check(plain_heal == int(player.get("heal_per_snack")) and belly_heal == roundi(plain_heal * 1.5),
		"Berry Belly: a snack heals %d HP, not %d" % [belly_heal, plain_heal])

	# Builder's Knack: 1 Wood less, never below 0, everywhere the cost shows.
	var fence: BuildingDefinition = BuildManager.get_definition(&"wooden_fence")
	var full_wood: int = int(fence.cost[&"wood"])
	_check(int(BuildManager.cost_of(fence).get(&"wood", 0)) == full_wood, "a fence costs %d Wood without the perk" % full_wood)
	_check(PerkManager.take(player, &"builders_knack"), "took Builder's Knack")
	_check(int(BuildManager.cost_of(fence).get(&"wood", 0)) == full_wood - 1, "Builder's Knack: a fence costs %d Wood" % (full_wood - 1))
	var cheap: BuildingDefinition = BuildingDefinition.new()
	cheap.cost = {&"wood": 1, &"stone": 2}
	var cheap_cost: Dictionary = BuildManager.cost_of(cheap)
	_check(not cheap_cost.has(&"wood") and int(cheap_cost.get(&"stone", 0)) == 2 and int(cheap.cost[&"wood"]) == 1,
		"Builder's Knack: a 1-Wood cost drops to nothing, never below 0")
	ResourceManager.add(&"wood", full_wood - 1 - ResourceManager.get_count(&"wood"))
	_check(ResourceManager.can_afford(BuildManager.cost_of(fence)) and not ResourceManager.can_afford(fence.cost),
		"Builder's Knack: %d Wood is enough for a fence" % (full_wood - 1))
	_check(BuildManager.enter_build_mode(fence), "build mode with the fence")
	await get_tree().process_frame
	var hud: Node = get_tree().get_first_node_in_group("hud")
	var shown: Array[String] = []
	for row in (hud.get("_build_row") as Node).get_children():
		if row is HBoxContainer and not row.is_queued_for_deletion():
			for label in row.find_children("*", "Label", true, false):
				shown.append((label as Label).text)
	_check(shown == ["%d" % (full_wood - 1)], "Builder's Knack: the build menu shows %s Wood" % ", ".join(shown))
	BuildManager.set("_is_valid", true)
	var blueprints_before: int = get_tree().get_nodes_in_group(Building.BLUEPRINT_GROUP).size()
	BuildManager.call("_try_confirm")
	var placed: Array[Node] = get_tree().get_nodes_in_group(Building.BLUEPRINT_GROUP)
	_check(placed.size() == blueprints_before + 1 and ResourceManager.get_count(&"wood") == 0,
		"Builder's Knack: placing a fence spends %d Wood" % (full_wood - 1))
	BuildManager.exit_build_mode()
	if placed.size() > blueprints_before:
		_check(BuildManager.remove_blueprint(placed[placed.size() - 1] as Building) and ResourceManager.get_count(&"wood") == full_wood - 1,
			"Builder's Knack: taking it back refunds the %d Wood paid" % (full_wood - 1))


## Plants a torch with the hero's Q action and returns it.
func _plant_torch(player: Node3D) -> Node3D:
	var before: Array[Node] = get_tree().get_nodes_in_group("torches")
	player.call("_try_place_torch")
	for node in get_tree().get_nodes_in_group("torches"):
		if not before.has(node):
			player.global_position += Vector3(0, 0, 2.0)
			return node as Node3D
	return null


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


func _bark_line(text: String, trigger: StringName, speaker: StringName) -> bool:
	for line in BarkLibrary.lines_for(trigger, speaker, GameManager.hero_id):
		if String((line as Dictionary).get("text", "")) == text:
			return true
	return false


func _start_fresh_run() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	# Level-ups take the first perk card at once, so the picker never
	# slows a scenario down. The perk scenarios turn it back on.
	PerkManager.auto_pick_seconds = 0.0
	# A fixed deal, so the cards taken (and their effects) are the same
	# every run. Scenarios that need a particular deal reseed after this.
	PerkManager.rng.seed = 1
	if _main != null:
		# Wait until the old camp is really gone: resuming from a physics-
		# frame timer, one process frame can still run before it is freed.
		var old: Node = _main
		old.queue_free()
		while is_instance_valid(old):
			await get_tree().process_frame
		GameManager.call("_reset_autoloads")
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	# The controls overlay pauses the game at run start; dismiss it.
	var overlay: Node = get_tree().get_first_node_in_group("controls_overlay")
	_check(overlay != null and overlay.is_open(), "controls overlay shown at run start")
	_check(get_tree().paused, "game paused while overlay open")
	overlay.close()
	_check(not get_tree().paused, "game unpaused after closing overlay")
	# Scenarios stage mobs next to the hero; only _check_auto_attack
	# lets the hero fight them on its own.
	for player in get_tree().get_nodes_in_group("player"):
		player.set("auto_attack", false)
	Engine.time_scale = SPEED


func _find_resource_node(item_id: StringName) -> ResourceNode:
	for node in get_tree().current_scene.find_children("*", "ResourceNode", true, false):
		var resource_node: ResourceNode = node as ResourceNode
		if resource_node.definition != null and resource_node.definition.id == item_id and resource_node.is_gatherable:
			return resource_node
	return null


func _campfire() -> BaseCore:
	return get_tree().get_first_node_in_group("base_core") as BaseCore


## Waits `game_seconds` of game time at the test speed. It uses SPEED,
## not Engine.time_scale, which a hit-stop briefly lowers.
func _wait(game_seconds: float) -> void:
	await get_tree().create_timer(game_seconds / SPEED, true, false, true).timeout


func _check(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok   - " + label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures += 1
	printerr("smoke: FAIL - " + label)


func _finish() -> void:
	Engine.time_scale = 1.0
	if _failures == 0:
		print("smoke: PASSED")
		get_tree().quit(0)
	else:
		printerr("smoke: FAILED (%d)" % _failures)
		get_tree().quit(1)


## Perk cards 05: the sibling cards work whichever hero is the player.
## Twin Strike hits harder only on a mob the other hero hit within
## HeroHits.TWIN_STRIKE_SECONDS; Cheer Up's level-ups heal the other hero.
func _run_perk_05_scenario() -> void:
	print("smoke: --- perk 05 scenario ---")
	for hero_id in [&"leo", &"nela"]:
		GameManager.set_party(hero_id)
		await _start_fresh_run()
		var player: Node3D = get_tree().get_first_node_in_group("player")
		var companion: Node3D = get_tree().get_first_node_in_group("companions")
		companion.set_physics_process(false)
		for building in get_tree().current_scene.find_children("*", "Building", true, false):
			building.set_physics_process(false)
		_check(HeroHits.other_hero(player) == companion and HeroHits.other_hero(companion) == player,
			"party %s: each hero's other hero is their sibling" % hero_id)
		for who in [player, companion]:
			await _check_perk_05_twin_strike(who, HeroHits.other_hero(who))
		for who in [player, companion]:
			_check_perk_05_cheer_up(who, HeroHits.other_hero(who))
	GameManager.set_party(&"leo")


func _check_perk_05_twin_strike(hero: Node3D, other: Node3D) -> void:
	var role: String = "player" if hero.is_in_group("player") else "companion"
	var spot: Vector3 = _campfire().global_position + Vector3(9, 0, 0)
	var beast_def: MobDefinition = load("res://resources/mobs/bramble_beast.tres") as MobDefinition
	var mob: Mob = _spawn_mob(beast_def, spot)
	var lone: Mob = _spawn_mob(beast_def, spot + Vector3(0, 0, 3))
	mob.set_physics_process(false)
	lone.set_physics_process(false)
	await get_tree().process_frame
	PerkManager.take(hero, &"twin_strike")
	var hits: Array[int] = []
	hits.append(HeroHits.strike(hero, lone, 4))  # nobody else on it
	hits.append(HeroHits.strike(hero, lone, 4))  # only its own hits
	HeroHits.strike(other, mob, 1)
	hits.append(HeroHits.strike(hero, mob, 4))  # the other hero just hit it
	await _wait(HeroHits.TWIN_STRIKE_SECONDS + 0.5)
	hits.append(HeroHits.strike(hero, mob, 4))  # too long ago
	_check(hits == [4, 4, 6, 4], "%s, Twin Strike: +50%% only on a mob the other hero just hit (%s)" % [role, hits])
	PerkManager.restore(hero, [])
	await _perk_04_clear_mobs()


func _check_perk_05_cheer_up(hero: Node3D, other: Node3D) -> void:
	var role: String = "player" if hero.is_in_group("player") else "companion"
	PerkManager.restore(hero, [])
	PerkManager.restore(other, [])
	other.set("current_hp", 10)
	ProgressionManager.award_xp(hero, ProgressionManager.get_xp_to_next_level(hero), &"test")
	var without: int = int(other.get("current_hp"))
	PerkManager.restore(hero, [&"cheer_up"])
	PerkManager.restore(other, [])
	ProgressionManager.award_xp(hero, ProgressionManager.get_xp_to_next_level(hero), &"test")
	var with_perk: int = int(other.get("current_hp"))
	var share: int = HeroHits.cheer_up_heal(other)
	_check(without == 10 and share > 0 and with_perk == 10 + share,
		"%s, Cheer Up: a level-up heals the other hero (%d -> %d, +%d)" % [role, without, with_perk, share])
	other.set("current_hp", int(other.get("max_hp")))
	PerkManager.restore(hero, [])
	PerkManager.restore(other, [])


## Perk cards 07: the centre banner ("NIGHT N!") hides while the perk
## picker is open, so it never sits on the picker's heading, and comes
## back once a card is taken.
func _run_perk_07_scenario() -> void:
	print("smoke: --- perk 07 scenario ---")
	await _start_fresh_run()
	PerkManager.auto_pick_seconds = 5.0
	var player: Node = get_tree().get_first_node_in_group("player")
	var hud: Node = get_tree().get_first_node_in_group("hud")
	var plate: Control = hud.get("_banner_plate") as Control
	hud.show_banner("Night 9!")
	await get_tree().create_timer(0.15, true, false, true).timeout
	_check(plate.modulate.a > 0.9, "the night banner shows (alpha %.2f)" % plate.modulate.a)
	ProgressionManager.award_xp(player, ProgressionManager.get_xp_to_next_level(player), &"test")
	var picker: PerkPicker = PerkManager.picker()
	_check(picker != null and is_zero_approx(plate.modulate.a) and hud.is_banner_hidden(),
		"the banner hides while the perk picker is open")
	if picker == null:
		return
	picker.pick(0)
	# The level-up restarted the banner (its own fade-in) under the picker.
	await get_tree().create_timer(0.15, true, false, true).timeout
	_check(plate.modulate.a > 0.9 and not hud.is_banner_hidden(), "the banner comes back once a card is taken (alpha %.2f)" % plate.modulate.a)


## Perk cards, review fixes: the companion never draws a player-only
## card; a card the dawn autosave missed (a picker still open, a level-up
## waiting behind it) is dealt again on Continue; Ember Heart torches and
## a blueprint's paid cost survive Continue; the Wood discount follows
## the perks; and stacking Twin Strike copies multiply.
func _run_perk_review_scenario() -> void:
	print("smoke: --- perk review scenario ---")
	await _start_fresh_run()
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var companion: Node3D = get_tree().get_first_node_in_group("companions")
	companion.set_physics_process(false)
	var player_only: Array = PerkManager.definitions().filter(func(p: PerkDefinition) -> bool: return p.player_only).map(
		func(p: PerkDefinition) -> StringName: return p.id)
	_check(player_only == [&"berry_belly", &"ember_heart"], "Berry Belly and Ember Heart are player-only cards (%s)" % [player_only])
	var companion_deal: Array[PerkDefinition] = PerkManager.offer(companion, 99)
	_check(not companion_deal.is_empty() and not companion_deal.any(func(p: PerkDefinition) -> bool: return p.player_only)
		and PerkManager.offer(player, 99).any(func(p: PerkDefinition) -> bool: return p.player_only),
		"the companion is never dealt a player-only card; the player is")

	# The dawn autosave lands while the picker is open, with one more
	# level-up queued behind it, and the companion is a card short too.
	PerkManager.auto_pick_seconds = 5.0
	ProgressionManager.award_xp(player, ProgressionManager.get_xp_to_next_level(player), &"test")
	ProgressionManager.award_xp(player, ProgressionManager.get_xp_to_next_level(player), &"test")
	ProgressionManager.award_xp(companion, ProgressionManager.get_xp_to_next_level(companion), &"test")
	ProgressionManager.award_xp(companion, ProgressionManager.get_xp_to_next_level(companion), &"test")
	PerkManager.restore(companion, PerkManager.perks_of(companion).slice(0, 1))
	_check(ProgressionManager.get_level(player) == 3 and PerkManager.is_picking() and PerkManager.perks_of(player).is_empty()
		and PerkManager.perks_of(companion).size() == 1, "saved mid-pick: the player holds 0 of 2 cards, the companion 1 of 2")
	var data: Dictionary = SaveManager.snapshot()
	PerkManager.close_picker()
	GameManager.set("_pending_save", SaveManager.parse(SaveManager.serialize(data)))
	await _start_fresh_run()
	await get_tree().process_frame
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	companion = get_tree().get_first_node_in_group("companions")
	companion.set_physics_process(false)
	var cards: Array[StringName] = PerkManager.perks_of(companion)
	_check(PerkManager.perks_of(player).size() == 2 and cards.size() == 2 and not PerkManager.is_picking(),
		"Continue deals the cards the save missed (player %s, companion %s)" % [PerkManager.perks_of(player), cards])
	# With the picker on, the top-up opens it, and queues the rest.
	PerkManager.auto_pick_seconds = 5.0
	PerkManager.restore(player, [])
	PerkManager.top_up(player)
	_check(PerkManager.is_picking() and int((PerkManager.get("_pending") as Dictionary).get(player, 0)) == 1,
		"a top-up of 2 cards opens the picker and queues the second")
	PerkManager.close_picker()
	PerkManager.auto_pick_seconds = 0.0
	PerkManager.restore(player, [])
	PerkManager.restore(companion, [])  # its Builder's Knack would count for the party

	# Builder's Knack: the cached discount follows taking and dropping it.
	var fence: BuildingDefinition = BuildManager.get_definition(&"wooden_fence")
	var full_wood: int = int(fence.cost[&"wood"])
	_check(int(BuildManager.cost_of(fence).get(&"wood", 0)) == full_wood, "no Builder's Knack: a fence costs %d Wood" % full_wood)
	PerkManager.take(player, &"builders_knack")
	_check(int(BuildManager.cost_of(fence).get(&"wood", 0)) == full_wood - 1, "Builder's Knack taken: the cost drops at once")
	PerkManager.restore(player, [])
	_check(int(BuildManager.cost_of(fence).get(&"wood", 0)) == full_wood, "Builder's Knack dropped: the cost is back at once")
	PerkManager.restore(player, [&"builders_knack", &"ember_heart"])

	# A blueprint paid for with the discount, and a burning Ember Heart
	# torch that has seen one dawn, both through save and Continue.
	ResourceManager.add(&"wood", full_wood)
	_check(BuildManager.enter_build_mode(fence), "build mode with the fence")
	await get_tree().process_frame
	BuildManager.set("_is_valid", true)
	var before: Array[Node] = get_tree().get_nodes_in_group(Building.BLUEPRINT_GROUP)
	BuildManager.call("_try_confirm")
	BuildManager.exit_build_mode()
	var blueprint: Building = null
	for node in get_tree().get_nodes_in_group(Building.BLUEPRINT_GROUP):
		if not before.has(node):
			blueprint = node as Building
	_check(blueprint != null and int((blueprint.get_meta(&"paid_cost", {}) as Dictionary).get(&"wood", 0)) == full_wood - 1,
		"the blueprint records the %d Wood paid" % (full_wood - 1))
	ResourceManager.add(&"torch", 1)
	var torch: Node3D = _plant_torch(player)
	if blueprint == null or torch == null:
		_check(false, "placed a blueprint and planted a torch")
		return
	torch.call("_on_dawn_started", TimeManager.day_number + 1)
	var radius: float = float(torch.get("radius"))
	var ring: float = (torch.get_node("Radius") as Node3D).scale.x
	var spot: Vector3 = torch.global_position
	var site: Vector3 = blueprint.global_position
	data = SaveManager.snapshot()
	var saved_torches: Array = data.get("torches", [])
	_check(saved_torches.size() == 1, "the save keeps the Ember Heart torch still burning (%d)" % saved_torches.size())
	torch.queue_free()
	blueprint.queue_free()
	GameManager.set("_pending_save", SaveManager.parse(SaveManager.serialize(data)))
	await _start_fresh_run()
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	var loaded_torch: Node3D = null
	for node in get_tree().get_nodes_in_group("torches"):
		if (node as Node3D).global_position.distance_to(spot) < 0.01:
			loaded_torch = node as Node3D
	_check(loaded_torch != null and is_equal_approx(float(loaded_torch.get("radius")), radius)
		and is_equal_approx((loaded_torch.get_node("Radius") as Node3D).scale.x, ring) and int(loaded_torch.get("dawns_to_burn")) == 1,
		"Continue keeps the Ember Heart torch: same spot, %.1f m, one dawn left" % radius)
	if loaded_torch != null:
		loaded_torch.call("_on_dawn_started", TimeManager.day_number + 1)
		_check(not loaded_torch.call("affects", loaded_torch.global_position), "the kept torch goes out at the next dawn")
	var loaded_print: Building = null
	for node in get_tree().get_nodes_in_group(Building.BLUEPRINT_GROUP):
		if (node as Building).definition == fence and (node as Building).global_position.distance_to(site) < 0.01:
			loaded_print = node as Building
	PerkManager.restore(player, [])  # the refund is what was paid, not today's price
	var wood_before: int = ResourceManager.get_count(&"wood")
	_check(loaded_print != null and BuildManager.remove_blueprint(loaded_print)
		and ResourceManager.get_count(&"wood") - wood_before == full_wood - 1,
		"after Continue, taking the blueprint back refunds the %d Wood paid" % (full_wood - 1))

	# Twin Strike, if it stacked: each copy multiplies.
	for building in get_tree().current_scene.find_children("*", "Building", true, false):
		building.set_physics_process(false)
	companion = get_tree().get_first_node_in_group("companions")
	var twin: PerkDefinition = PerkManager.get_definition(&"twin_strike")
	var stacked: bool = twin.stacks
	twin.stacks = true
	PerkManager.restore(player, [&"twin_strike", &"twin_strike"])
	var beast_def: MobDefinition = load("res://resources/mobs/bramble_beast.tres") as MobDefinition
	var mob: Mob = _spawn_mob(beast_def, _campfire().global_position + Vector3(9, 0, 0))
	mob.set_physics_process(false)
	await get_tree().process_frame
	HeroHits.strike(companion, mob, 1)
	var factor: float = HeroHits.damage_factor(player, mob)
	_check(is_equal_approx(factor, twin.value * twin.value), "two Twin Strike copies multiply (x%.2f)" % factor)
	twin.stacks = stacked
	PerkManager.restore(player, [])
	await _perk_04_clear_mobs()


## Hero core 01: Leo and Nela take hits, heal and go down the same way
## in both roles, through the Hero interface. The companion revives at
## dawn; the player's hero going down ends the run.
func _run_hero_health_scenario() -> void:
	print("smoke: --- hero health scenario ---")
	for hero_id in [&"leo", &"nela"]:
		GameManager.set_party(hero_id)
		await _start_fresh_run()
		var player: Hero = get_tree().get_first_node_in_group("player") as Hero
		var companion: Hero = get_tree().get_first_node_in_group("companions") as Hero
		_check(player != null and companion != null, "party %s: both roles are Heroes" % hero_id)
		if player == null or companion == null:
			continue
		for who in [player, companion]:
			_check_hero_health(who as Hero)
		# The companion goes down, then gets back up at dawn.
		var downs: Array[bool] = []
		companion.down_changed.connect(func(is_down: bool) -> void: downs.append(is_down))
		companion.clear_invulnerability()
		companion.take_damage(9999)
		var label: String = "%s as companion" % _hero_id(companion)
		_check(companion.is_down() and companion.current_hp == 0 and downs == [true],
			"%s: going down emits down_changed(true) (%s)" % [label, downs])
		companion.clear_invulnerability()
		companion.take_damage(5)
		companion.heal(5)
		_check(companion.current_hp == 0, "%s: no hits or heals while down" % label)
		var t: int = 0
		while companion.is_down() and t < 4:
			TimeManager.skip_phase()
			t += 1
		_check(not companion.is_down() and companion.current_hp == companion.max_hp and downs == [true, false],
			"%s: revives at dawn at full HP (%d/%d, %s)" % [label, companion.current_hp, companion.max_hp, downs])
		# The player's hero going down ends the run.
		var player_downs: Array[bool] = []
		player.down_changed.connect(func(is_down: bool) -> void: player_downs.append(is_down))
		player.clear_invulnerability()
		player.take_damage(9999)
		label = "%s as player" % _hero_id(player)
		_check(player.is_down() and player_downs == [true], "%s: going down emits down_changed(true)" % label)
		_check(GameManager.run_state == GameManager.RunState.LOST and GameManager.end_trigger == &"loss_hero",
			"%s: being down ends the run (%s)" % [label, GameManager.end_reason])
	GameManager.set_party(&"leo")


## A hit lowers HP, the invulnerability window blocks a second one, and
## a heal raises it again.
func _check_hero_health(who: Hero) -> void:
	var label: String = "%s as %s" % [_hero_id(who), "player" if who.is_in_group("player") else "companion"]
	who.heal(who.max_hp)
	who.clear_invulnerability()
	var full: int = who.current_hp
	who.take_damage(6)
	var hit: int = who.current_hp
	_check(hit < full and who.is_invulnerable(), "%s: a hit lowers HP (%d -> %d)" % [label, full, hit])
	who.take_damage(6)
	_check(who.current_hp == hit, "%s: the invulnerability window blocks a second hit" % label)
	who.heal(3)
	_check(who.current_hp == mini(who.max_hp, hit + 3), "%s: a heal raises HP (%d -> %d)" % [label, hit, who.current_hp])
	_check(not who.is_down(), "%s: still up" % label)


func _hero_id(who: Node) -> StringName:
	var definition: HeroDefinition = who.get("hero") as HeroDefinition
	return definition.id if definition != null else &"?"
