extends "res://tests/automated/smoke_scenario.gd"

## The story: its data, the storybooks and story cards, the shard drops
## and the Moon Lantern, and Mum.


func run() -> void:
	await _run_story_scenario()


## The story data, the intro storybook and the chapters; shard drops
## and the Moon Lantern; Mum's portraits, her walk home and her seat at
## the title; the team's paintings and models.
func _run_story_scenario() -> void:
	print("smoke: --- story scenario ---")
	_check(StoryLibrary.chapter_name(1) == "The Dark Moon" and StoryLibrary.chapter_name(2) == "Into the Hollow", "chapter names")
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
	_check(GameManager.intro_pages(RunConfig.for_chapter(1)).size() == 4, "a seen intro still opens the next new game")
	StoryLibrary.forget_progress()

	# Shards: a chance per kill with pity, per mob type (seeded).
	var imp_def: MobDefinition = load("res://resources/mobs/shadow_imp.tres") as MobDefinition
	var beast_def: MobDefinition = load("res://resources/mobs/bramble_beast.tres") as MobDefinition
	RunSession.reset(_config(0.0, 1, 36))
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
	# A card still talking is never cut short, and dawn
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
	var data: Dictionary = RunSession.snapshot()
	_check(int(data["lantern"]["shards"]) == lantern.shards, "the save holds the lantern's shards")
	var legacy: Dictionary = data.duplicate(true)
	legacy.erase("lantern")
	await _continue_from(SaveManager.parse(SaveManager.serialize(data)))
	lantern = MoonLantern.find(get_tree())
	_check(lantern.is_full(), "Continue keeps the lantern lit (stage %d)" % lantern.stage)
	await _continue_from(legacy)
	_check(MoonLantern.find(get_tree()).stage == 0, "older saves start the lantern dark")
	await _start_fresh_run(_run_of(RunConfig.for_chapter(2)))
	_check(MoonLantern.find(get_tree()).max_stage() == 6, "Chapter 2's lantern has 6 stages")

	# Mum's portraits, her walk home, and her seat at the title.
	_check(StoryLibrary.speaker_portrait("mum", "worried").resource_path.ends_with("mum_worried.png")
		and StoryLibrary.speaker_portrait("mum").resource_path.ends_with("mum.png")
		and StoryLibrary.speaker_portrait("mum", "nope").resource_path.ends_with("mum.png"), "Mum's expressions, with a fallback")
	# The team's paintings, the kids' faces, the lantern model.
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
