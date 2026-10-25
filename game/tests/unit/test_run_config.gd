extends "res://tests/unit/unit_test.gd"

## The run config: its rules for each chapter and an endless run, how a
## config is built, Again, the day chest roll and the save round trip.

## A save from before the chapter, endless mode and the day chest were
## stored: a Chapter 1 run on day 1.
const V2_SAVE_FIXTURE: String = "res://tests/fixtures/save_v2_day1.json"


func test_chapter_1_rules() -> void:
	var run: RunConfig = RunConfig.for_chapter(1)
	check(not run.has_moon_eater(), "Chapter 1 has no Moon-Eater")
	for night in [1, 2, 3, 4]:
		check(not run.is_moon_eater_night(night), "Chapter 1's night %d is not the Moon-Eater's" % night)
	check(not run.dawn_wins(2), "Chapter 1's dawn 2 does not win")
	check(run.dawn_wins(3), "Chapter 1's dawn 3 wins")
	check(run.dawn_wins(4), "a dawn past Chapter 1's goal wins")
	check_eq(run.nights_past_story(5), 0, "Chapter 1 is never past the story")
	check(not run.lantern_starts_full(), "Chapter 1's Moon Lantern starts dark")
	check(run.plays_intro(), "Chapter 1 plays its intro")


func test_chapter_2_rules() -> void:
	var run: RunConfig = RunConfig.for_chapter(2)
	check(run.has_moon_eater(), "Chapter 2 has a Moon-Eater")
	check(not run.is_moon_eater_night(6), "Chapter 2's night 6 is not the Moon-Eater's")
	check(run.is_moon_eater_night(7), "Chapter 2's night 7 is the Moon-Eater's")
	check(not run.is_moon_eater_night(8), "Chapter 2's night 8 is not the Moon-Eater's")
	check(not run.dawn_wins(6), "Chapter 2's dawn 6 does not win")
	check(run.dawn_wins(7), "Chapter 2's dawn 7 wins")
	check_eq(run.nights_past_story(9), 0, "Chapter 2 is never past the story")
	check(not run.lantern_starts_full(), "Chapter 2's Moon Lantern starts dark")
	check(run.plays_intro(), "Chapter 2 plays its intro")


func test_endless_rules() -> void:
	var run: RunConfig = RunConfig.for_endless()
	check(not run.has_moon_eater(), "an endless run has no Moon-Eater")
	for night in [6, 7, 8]:
		check(not run.is_moon_eater_night(night), "an endless run's night %d is not the Moon-Eater's" % night)
	for night in [6, 7, 8, 20]:
		check(not run.dawn_wins(night), "an endless run's dawn %d does not win" % night)
	check_eq(run.nights_past_story(6), 0, "an endless run's night 6 is not past the story")
	check_eq(run.nights_past_story(7), 0, "an endless run's night 7 is the story's last")
	check_eq(run.nights_past_story(8), 1, "an endless run's night 8 is 1 past the story")
	check_eq(run.nights_past_story(10), 3, "an endless run's night 10 is 3 past the story")
	check(run.lantern_starts_full(), "an endless run's Moon Lantern starts full")
	check(not run.plays_intro(), "an endless run plays no intro")


func test_a_config_for_a_chapter_gets_its_nights() -> void:
	var one: RunConfig = RunConfig.for_chapter(1)
	check_eq(one.chapter, 1, "a config for Chapter 1 is Chapter 1")
	check_eq(one.nights_to_win, 3, "Chapter 1 is 3 nights")
	check(not one.endless, "a config for Chapter 1 is a story run")
	var two: RunConfig = RunConfig.for_chapter(2)
	check_eq(two.chapter, 2, "a config for Chapter 2 is Chapter 2")
	check_eq(two.nights_to_win, 7, "Chapter 2 is 7 nights")
	check(not two.endless, "a config for Chapter 2 is a story run")


func test_a_config_for_endless_is_chapter_2_endless() -> void:
	var run: RunConfig = RunConfig.for_endless()
	check_eq(run.chapter, 2, "an endless config is Chapter 2")
	check_eq(run.nights_to_win, 7, "an endless config has Chapter 2's 7 nights")
	check(run.endless, "an endless config has the endless flag")


func test_again_keeps_the_run_and_gives_new_seeds() -> void:
	var last: RunConfig = RunConfig.for_endless()
	last.hero_id = &"nela"
	last.companion_id = &"leo"
	last.starting_perk = &"ember_heart"
	last.perk_auto_pick_seconds = 0.0
	var next: RunConfig = last.again()
	check(next != last, "Again builds a new config")
	check_eq(next.hero_id, &"nela", "Again keeps the hero")
	check_eq(next.companion_id, &"leo", "Again keeps the companion")
	check_eq(next.chapter, 2, "Again keeps the chapter")
	check(next.endless, "Again keeps the endless mode")
	check_eq(next.nights_to_win, 7, "Again keeps the nights to win")
	check_eq(next.starting_perk, &"ember_heart", "Again keeps the starting perk")
	check_eq(next.perk_auto_pick_seconds, 0.0, "Again keeps the auto-pick time")
	check(next.perk_seed != last.perk_seed, "Again deals the perks from a new seed")
	check(next.loot_seed != last.loot_seed, "Again rolls the loot from a new seed")
	check(next.chest_seed != last.chest_seed, "Again rolls the day chest from a new seed")
	var story: RunConfig = RunConfig.for_chapter(1).again()
	check(story.chapter == 1 and not story.endless and story.nights_to_win == 3,
		"Again after Chapter 1 is Chapter 1 again")


func test_the_same_seed_gives_the_same_day_chest_day() -> void:
	var days: Dictionary = {}
	for seed in [1, 2, 3, 42, 1234, 99991]:
		var first: RunConfig = RunConfig.for_chapter(2)
		first.chest_seed = seed
		var second: RunConfig = RunConfig.for_chapter(2)
		second.chest_seed = seed
		var day: int = first.roll_day_chest(0.5)
		check_eq(second.roll_day_chest(0.5), day, "chest seed %d rolls the same day twice" % seed)
		check_eq(first.roll_day_chest(0.5), day, "chest seed %d rolls the same day again" % seed)
	for seed in 200:
		var run: RunConfig = RunConfig.for_chapter(2)
		run.chest_seed = seed
		days[run.roll_day_chest(0.5)] = true
	check(days.has(0), "some seeds roll no day chest")
	check(days.keys().all(func(day: int) -> bool: return day >= 0 and day <= 7),
		"a rolled day chest comes on one of the run's 7 days")
	check(days.size() == 8, "every day of the run can have the chest (%d of 8)" % days.size())
	var always: RunConfig = RunConfig.for_chapter(1)
	check(always.roll_day_chest(1.0) > 0, "a sure chance always rolls a chest")
	check_eq(always.roll_day_chest(0.0), 0, "no chance never rolls a chest")
	var built: RunConfig = RunConfig.for_chapter(1)
	check_eq(built.day_chest_day, built.roll_day_chest(RunConfig.DAY_CHEST_CHANCE),
		"a config for a chapter has its own seed's chest day")


func test_the_save_round_trip() -> void:
	var run: RunConfig = RunConfig.for_endless()
	run.hero_id = &"nela"
	run.companion_id = &"leo"
	run.day_chest_day = 4
	var data: Dictionary = {"day": 5, "stats": {"kills": 3}}
	run.write_save(data)
	check_eq(data["day"], 5, "the config leaves the save's other keys alone")
	check_eq(data["nights_to_win"], 7, "the config writes the run length")
	check_eq(data["endless"], true, "the config writes the endless flag")
	check_eq(data["party"], {"hero": "nela", "companion": "leo"}, "the config writes the party")
	check_eq(data["day_chest_day"], 4, "the config writes the day chest's day")
	var back: RunConfig = RunConfig.from_save(JSON.parse_string(JSON.stringify(data)))
	check_eq(back.chapter, 2, "an endless run reads back as Chapter 2")
	check(back.endless, "an endless run reads back as endless")
	check_eq(back.nights_to_win, 7, "the run length reads back")
	check_eq(back.hero_id, &"nela", "the hero reads back")
	check_eq(back.companion_id, &"leo", "the companion reads back")
	check_eq(back.day_chest_day, 4, "the day chest's day reads back")

	var story: Dictionary = {}
	RunConfig.for_chapter(1).write_save(story)
	var one: RunConfig = RunConfig.from_save(JSON.parse_string(JSON.stringify(story)))
	check(one.chapter == 1 and not one.endless and one.nights_to_win == 3,
		"a Chapter 1 run reads back as Chapter 1")
	# A stored chapter wins over the run length.
	var odd: RunConfig = RunConfig.for_chapter(1)
	odd.nights_to_win = 9
	var odd_data: Dictionary = {}
	odd.write_save(odd_data)
	check_eq(RunConfig.from_save(JSON.parse_string(JSON.stringify(odd_data))).chapter, 1,
		"a stored chapter is read back, not guessed from the run length")


func test_the_v2_save_fixture_reads_back() -> void:
	var data: Dictionary = SaveManager.parse(FileAccess.get_file_as_string(V2_SAVE_FIXTURE))
	check(not data.is_empty(), "the v2 save fixture parses")
	var run: RunConfig = RunConfig.from_save(data)
	check_eq(run.chapter, 1, "the v2 save is Chapter 1, from its 3 nights")
	check(not run.endless, "the v2 save is a story run")
	check_eq(run.nights_to_win, 3, "the v2 save keeps its 3 nights")
	check_eq(run.hero_id, &"leo", "the v2 save's hero is Leo")
	check_eq(run.companion_id, &"nela", "the v2 save's companion is Nela")
	check_eq(run.day_chest_day, 0, "the v2 save, from before the day chest, has none")


func test_a_save_from_before_endless_reads_back() -> void:
	var data: Dictionary = SaveManager.parse(FileAccess.get_file_as_string(V2_SAVE_FIXTURE))
	data["nights_to_win"] = 7.0  # JSON numbers read back as floats
	data.erase("party")
	var run: RunConfig = RunConfig.from_save(data)
	check_eq(run.chapter, 2, "a 7-night save from before the chapter was stored is Chapter 2")
	check(not run.endless, "a save from before endless mode is a story run")
	check(run.has_moon_eater(), "it keeps its Moon-Eater")
	check(run.hero_id == &"leo" and run.companion_id == &"nela",
		"a save from before hero select is Leo with Nela")
	data["endless"] = true
	var endless: RunConfig = RunConfig.from_save(data)
	check(endless.chapter == 2 and endless.endless,
		"an endless save from before the chapter was stored is Chapter 2, endless")


func test_the_party_falls_back_to_known_heroes() -> void:
	var run: RunConfig = RunConfig.for_chapter(1)
	run.set_party(&"nela")
	check(run.hero_id == &"nela" and run.companion_id == &"leo", "Leo comes along when Nela is played")
	check_eq(run.hero().id, &"nela", "the config's hero is Nela's definition")
	check_eq(run.companion().id, &"leo", "the config's companion is Leo's definition")
	run.set_party(&"nobody", &"nobody")
	check_eq(run.hero_id, &"leo", "an unknown hero is Leo")
	check(run.companion_id != &"leo" and run.companion_id != &"nobody", "an unknown companion is the hero's default")
	run.set_party(&"leo", &"leo")
	check(run.companion_id != &"leo", "the hero is never their own companion")
