extends "res://tests/automated/smoke_scenario.gd"

## Starting perks that badges unlock, picked in hero select.


func run() -> void:
	await _run_starting_perks_scenario()


## A badge unlocks a starting perk. Without it hero
## select offers none and a run starts with no card even if one is asked
## for. With Gatherer earned, hero select offers Quick Hands; the pick
## reaches the next run, which starts holding it (gathering is faster),
## and it never takes the place of a level-up card, through Continue too.
func _run_starting_perks_scenario() -> void:
	print("smoke: --- starting perks scenario ---")
	Profile.delete()
	_check(StartingPerks.unlocked().is_empty(), "no starting perk is unlocked on a fresh profile")
	var screen: Node = (load("res://scenes/ui/HeroSelect.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	var row: Control = screen.get("starting_perk_row") as Control
	_check(row == null or not row.visible, "hero select offers no starting perk without the unlock")
	screen.queue_free()
	await get_tree().process_frame
	var config: RunConfig = _config()
	config.starting_perk = &"quick_hands"
	await _start_fresh_run(config)
	_check(PerkManager.perks_of(Party.player_hero()).is_empty(), "a locked starting perk is not given")

	# Earn Gatherer: Quick Hands is offered and picked in hero select.
	Profile.grant_badge_for_tests(&"gatherer")
	_check(StartingPerks.unlocked().has(&"quick_hands"), "Gatherer unlocks Quick Hands as a starting perk")
	screen = (load("res://scenes/ui/HeroSelect.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	row = screen.get("starting_perk_row") as Control
	_check(row != null and row.visible, "hero select shows the starting perk row once unlocked")
	screen.call("pick_starting_perk", &"quick_hands")
	screen.queue_free()
	await get_tree().process_frame
	Profile.reload()
	_check(StartingPerks.chosen() == &"quick_hands", "the pick is kept for the next run, after a restart too")
	config = _config(5.0)  # the level-up below opens the picker
	config.starting_perk = StartingPerks.chosen()  # as hero select's Go puts it on the run config
	await _start_fresh_run(config)
	var player: Hero = Party.player_hero()
	var tree_node: ResourceNode = _find_resource_node(&"wood")
	_check(PerkManager.perks_of(player) == [&"quick_hands"] and PerkManager.perks_of(Party.companion()).is_empty()
		and not PerkManager.is_picking(), "the run starts with the chosen perk, no picker")
	_check(is_equal_approx(tree_node.gather_seconds_for(player), tree_node.gather_time_seconds * 0.7),
		"the starting Quick Hands speeds up gathering")

	# A level-up still deals its own card, even when saved with it owed.
	ProgressionManager.award_xp(player, ProgressionManager.get_xp_to_next_level(player), &"test")
	_check(PerkManager.is_picking(), "the first level-up still opens the picker")
	var data: Dictionary = SaveManager.parse(SaveManager.serialize(RunSession.snapshot()))
	await _continue_from(data)
	await get_tree().process_frame
	player = Party.player_hero()
	_check(PerkManager.perks_of(player).size() == 2 and PerkManager.has(player, &"quick_hands"),
		"after Continue the starting perk is kept and the owed card is dealt (%s)" % [PerkManager.perks_of(player)])
	StartingPerks.choose(&"")
	Profile.delete()
