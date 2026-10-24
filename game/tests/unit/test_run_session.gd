extends "res://tests/unit/unit_test.gd"

## The run session holds the run config: Continue builds it from the
## save, a reset keeps it, and forgetting the last run puts back a fresh
## Chapter 1 run of Leo with Nela. The game manager saves none of the
## config's keys. The last run is forgotten after each test.

## A save from before the chapter, endless mode and the day chest were
## stored: a Chapter 1 run on day 1.
const V2_SAVE_FIXTURE: String = "res://tests/fixtures/save_v2_day1.json"


func after_each() -> void:
	RunSession.forget_last_run()
	Profile.use_memory()  # a test that picks a starting perk leaves none behind


func test_continue_takes_the_run_from_the_v2_save() -> void:
	var data: Dictionary = SaveManager.parse(FileAccess.get_file_as_string(V2_SAVE_FIXTURE))
	data["nights_to_win"] = 7.0  # JSON numbers read back as floats
	check(RunSession.continue_from(data, null, false), "the run session takes the v2 save")
	var run: RunConfig = RunSession.config
	check_eq(run.nights_to_win, 7, "Continue resumes at the saved run length")
	check_eq(run.chapter, 2, "Continue resumes a 7-night save as Chapter 2")
	check(not run.endless, "Continue resumes the v2 save as a story run")
	check(run.hero_id == &"leo" and run.companion_id == &"nela", "Continue resumes the v2 save's party")


func test_continue_keeps_an_endless_run_endless() -> void:
	var data: Dictionary = {"version": SaveManager.VERSION, "day": 8, "nights_to_win": 7.0, "endless": true,
		"party": {"hero": "nela", "companion": "leo"}}
	RunSession.continue_from(data, null, false)
	check(RunSession.config.endless and RunSession.config.chapter == 2, "an endless save continues as endless")
	check_eq(RunSession.config.hero_id, &"nela", "an endless save continues with its hero")


func test_continue_takes_the_seeds_from_the_given_config() -> void:
	var seeds: RunConfig = RunConfig.for_endless()
	seeds.perk_seed = 11
	seeds.loot_seed = 12
	seeds.chest_seed = 13
	seeds.perk_auto_pick_seconds = 0.0
	var data: Dictionary = {"version": SaveManager.VERSION, "day": 1, "nights_to_win": 3.0}
	RunSession.continue_from(data, seeds, false)
	var run: RunConfig = RunSession.config
	check(run.chapter == 1 and not run.endless, "the shape comes from the save, not the given config")
	check(run.perk_seed == 11 and run.loot_seed == 12 and run.chest_seed == 13,
		"the seeds come from the given config")
	check_eq(run.perk_auto_pick_seconds, 0.0, "the auto-pick time comes from the given config")


func test_again_after_a_continue_starts_with_the_starting_perk_picked() -> void:
	Profile.use_memory()  # never the player's own profile
	Profile.grant_badge_for_tests(StartingPerks.UNLOCKS[&"quick_hands"])
	StartingPerks.choose(&"quick_hands")
	var data: Dictionary = {"version": SaveManager.VERSION, "day": 2, "nights_to_win": 3.0}
	RunSession.continue_from(data, null, false)
	check_eq(RunSession.config.again().starting_perk, &"quick_hands",
		"Again after a Continue starts with the starting perk picked")


func test_a_reset_keeps_the_config() -> void:
	var run: RunConfig = RunConfig.for_chapter(2)
	RunSession.reset(run)
	RunSession.reset()
	check(RunSession.config == run, "a reset with no config keeps the run's config")
	RunSession.forget_last_run()
	check(RunSession.config != run, "forgetting the last run drops its config")
	check(RunSession.config.chapter == 1 and not RunSession.config.endless and RunSession.config.nights_to_win == 3,
		"after forgetting, the run is a 3-night Chapter 1 story run")
	check(RunSession.config.hero_id == &"leo" and RunSession.config.companion_id == &"nela",
		"after forgetting, the party is Leo with Nela")


func test_the_game_manager_saves_no_config_key() -> void:
	var saved: Dictionary = GameManager.save_state()
	for key in ["nights_to_win", "endless", "party", "day_chest_day", "chapter"]:
		check(not saved.has(key), "the game manager does not save \"%s\"" % key)
	check(saved.has("stats") and saved.has("loot_misses"), "the game manager still saves the stats and loot misses")
