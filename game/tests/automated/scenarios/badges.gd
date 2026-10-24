extends "res://tests/automated/smoke_scenario.gd"

## Badges: earned in play and kept in the profile across runs and
## restarts, and the scrapbook's Badges tab that lists them.


func run() -> void:
	await _run_badges_scenario()
	await _run_scrapbook_scenario()


## Surviving night 1 earns First Night once, with a
## toast, and it is still earned after a restart (the profile read again
## from its file). The totals counting badges need (Builder, Gremlin
## Catcher) carry across runs and restarts. Winning Chapter 1 with the
## fire kept above half earns Chapter 1 and Fire Keeper.
func _run_badges_scenario() -> void:
	print("smoke: --- badges scenario ---")
	Profile.delete()
	var earned: Array[StringName] = []
	var on_earned: Callable = func(badge: BadgeDefinition) -> void: earned.append(badge.id)
	Profile.badge_earned.connect(on_earned)
	var config: RunConfig = _config()
	config.hero_id = &"leo"
	config.companion_id = &"nela"
	config.nights_to_win = 3
	config.endless = false
	await _start_fresh_run(config)
	_check(not Profile.is_badge_earned(&"first_night"), "First Night is not earned before a night is survived")
	await _skip_to_dawn(1)
	var hud: Node = get_tree().get_first_node_in_group("hud")
	var toasted: bool = false
	for toast in hud.call("toasts"):
		toasted = toasted or (toast as HudToast).text().contains("First Night")
	_check(Profile.is_badge_earned(&"first_night") and toasted, "surviving night 1 earns First Night, with a toast")
	await _skip_to_dawn(2)
	_check(earned.count(&"first_night") == 1, "First Night is earned once, not again on night 2")

	# The counting badges: a gremlin caught for real, then the rest.
	var gremlin: MobDefinition = load("res://resources/mobs/mushroom_gremlin.tres") as MobDefinition
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	var thief: Mob = _spawn_mob(gremlin, player.global_position + Vector3(6, 0, 0))
	thief.take_damage(999, player)
	_check(int(GameManager.stats[&"gremlins_caught"]) == 1 and Profile.stat_total(&"gremlins_caught") == 1,
		"catching a gremlin counts it, this run and in total")
	GameManager.record(&"gremlins_caught", 5)
	GameManager.record(&"built", 30)
	_campfire().take_damage(_campfire().get_max_hp() / 4)
	_check(int(GameManager.stats[&"fire_low_pct"]) <= 75, "the fire's lowest HP is kept (%d%%)" % GameManager.stats[&"fire_low_pct"])
	_campfire().take_damage(10000)
	await get_tree().process_frame
	_check(GameManager.run_state == GameManager.RunState.LOST, "the first badges run is lost")
	_check(not Profile.is_badge_earned(&"builder") and not Profile.is_badge_earned(&"gremlin_catcher") and not Profile.is_badge_earned(&"chapter_1"),
		"Builder, Gremlin Catcher and Chapter 1 are not earned yet")

	# A restart, then a second run: the totals carry on.
	Profile.reload()
	_check(Profile.is_badge_earned(&"first_night"), "First Night is still earned after a restart")
	_check(Profile.stat_total(&"built") == 30 and Profile.stat_total(&"gremlins_caught") == 6,
		"the totals survive a restart (built %d, gremlins %d)" % [Profile.stat_total(&"built"), Profile.stat_total(&"gremlins_caught")])
	await _start_fresh_run(config)
	_check(int(GameManager.stats[&"gremlins_caught"]) == 0 and int(GameManager.stats[&"fire_low_pct"]) == 100
		and int(GameManager.stats[&"lantern_lit"]) == 0, "a new run starts its badge stats afresh")
	GameManager.record(&"built", 19)
	_check(not Profile.is_badge_earned(&"builder"), "49 buildings in total is not yet Builder")
	GameManager.record(&"built")
	GameManager.record(&"gremlins_caught", 4)
	_check(Profile.is_badge_earned(&"builder") and Profile.is_badge_earned(&"gremlin_catcher"),
		"Builder and Gremlin Catcher are earned from totals across runs")
	await _skip_to_dawn(1)
	_check(earned.count(&"first_night") == 1, "First Night is not earned again in a later run")
	await _skip_to_dawn(3)
	_check(GameManager.run_state == GameManager.RunState.WON and Profile.is_badge_earned(&"chapter_1"),
		"winning Chapter 1 earns the Chapter 1 badge")
	var end_screen: Node = get_tree().get_first_node_in_group("end_screen")
	var listed: PackedStringArray = end_screen.call("badges_text") if end_screen != null else PackedStringArray()
	var chapter_1_name: String = Badges.get_badge(&"chapter_1").display_name
	_check(listed.has(chapter_1_name) and not listed.has(Badges.get_badge(&"first_night").display_name),
		"the end screen lists the badges this run earned, the win's own among them (%s)" % ", ".join(listed))
	_check(Profile.is_badge_earned(&"fire_keeper") == (int(GameManager.stats[&"fire_low_pct"]) >= 50),
		"Fire Keeper follows the fire's lowest HP (%d%%)" % GameManager.stats[&"fire_low_pct"])
	_check(Profile.has_won_with(&"leo") and not Profile.is_badge_earned(&"both_heroes"), "Both Heroes waits for a win as Nela")
	Profile.badge_earned.disconnect(on_earned)
	Profile.delete()


## The title's Journal button opens the scrapbook,
## whose Badges tab lists every badge: the earned ones in colour, the
## locked ones as silhouettes with how to earn them, as the profile has
## them. Close goes back to the title.
func _run_scrapbook_scenario() -> void:
	print("smoke: --- scrapbook scenario ---")
	Profile.delete()
	for id in [&"first_night", &"builder"]:
		Profile.grant_badge_for_tests(id)
	var game_camera: Camera3D = get_viewport().get_camera_3d()
	var title: Control = (load("res://scenes/ui/TitleScreen.tscn") as PackedScene).instantiate()
	add_child(title)
	await get_tree().process_frame
	var journal: Button = title.call("journal_button") as Button
	_check(journal != null and not journal.disabled, "the title has a Journal button")
	journal.pressed.emit()
	await get_tree().process_frame
	var book: Control = title.call("scrapbook") as Control
	_check(book != null and book.is_visible_in_tree(), "the Journal button opens the scrapbook")
	if book != null:
		_check(book.call("current_tab") == "Badges", "the scrapbook opens on its Badges tab")
		var shown: Dictionary = book.call("badge_states")
		var all: Array[BadgeDefinition] = Badges.definitions()
		_check(shown.size() == all.size() and all.size() >= 15,
			"the Badges tab lists every badge (%d of %d)" % [shown.size(), all.size()])
		var matches: bool = true
		for badge in all:
			matches = matches and shown.has(badge.id) and bool(shown[badge.id]) == Profile.is_badge_earned(badge.id)
		_check(matches and bool(shown.get(&"first_night")) and not bool(shown.get(&"chapter_1", true)),
			"earned and locked badges match the profile")
		var fire_keeper: BadgeDefinition = Badges.get_badge(&"fire_keeper")
		var locked_text: String = book.call("badge_text", &"fire_keeper")
		_check(locked_text.contains(fire_keeper.how_to_earn), "a locked badge says how to earn it")
		(book.call("close_button") as Button).pressed.emit()
		await get_tree().process_frame
		_check(not is_instance_valid(book) or not book.is_visible_in_tree(), "Close leaves the scrapbook for the title")
	title.free()
	if game_camera != null and is_instance_valid(game_camera):
		game_camera.make_current()
	Profile.delete()
