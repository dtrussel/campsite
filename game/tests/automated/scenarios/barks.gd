extends "res://tests/automated/smoke_scenario.gd"

## The siblings' barks over their heads, as either hero is played.


func run() -> void:
	await _run_bark_scenario()


## The siblings' barks. The right hero speaks, keyed by who
## is played; cooldowns hold back spam; a bark never cuts off a story
## voice; the companion warns about a mob behind the player.
func _run_bark_scenario() -> void:
	print("smoke: --- bark scenario ---")
	await _start_fresh_run(_party(&"leo"))
	# A first run's story card holds barks back; this checks them alone.
	await _close_story()
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
	_check(SpeechBubble.on(companion).position.y > (companion as Hero).health_bar().position.y,
		"the bubble sits above the health bar")
	# A gremlin that gets away, and the first beast once a run.
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
	# Wait for the director's next poll in game time, frame by frame: on a
	# slow machine one frame can cover a whole poll interval, so a fixed
	# real-time wait can end on the frame before the poll runs.
	var warned: Callable = func() -> bool:
		var said: SpeechBubble = SpeechBubble.on(companion)
		return said != null and _bark_line(said.text, &"danger_behind", &"nela")
	var waited: float = 0.0
	while not warned.call() and waited < BarkDirector.DANGER_POLL_SECONDS * 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(warned.call(), "Nela warns: behind you! (%.1fs)" % waited)
	director.clock += 30.0
	companion.call("take_damage", 9999)
	_check(_bark_line(SpeechBubble.on(player).text, &"companion_down", &"leo"), "Leo calls out when Nela is knocked out")
	director.clock += 30.0
	_check(not director.bark(&"danger_behind"), "a knocked-out companion gives no warnings")
	imp.take_damage(999, player)

	# Nela played: the speakers swap, and the events reach the director.
	await _start_fresh_run(_party(&"nela"))
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
