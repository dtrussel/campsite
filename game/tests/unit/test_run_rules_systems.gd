extends "res://tests/unit/unit_test.gd"

## The systems that play the run's rules ask the run config the run
## session holds: the mob spawner's Moon-Eater, eyes and endless
## toughness, the Moon Lantern's stages, and whether the
## chapter intro plays. Each test resets the run session to a config,
## and forgets it after.


func test_spawner_in_chapter_2() -> void:
	RunSession.reset(RunConfig.for_chapter(2))
	var spawner: MobSpawner = _spawner()
	check(spawner.is_boss_night(7) and not spawner.is_boss_night(6), "Chapter 2: the Moon-Eater comes on night 7")
	check(spawner.is_eyes_night(5) and spawner.is_eyes_night(6), "Chapter 2: its eyes watch on nights 5 and 6")
	check(not spawner.is_eyes_night(4) and not spawner.is_eyes_night(7), "Chapter 2: no eyes on night 4 or its own night")
	check_eq(spawner.endless_nights_past(9), 0, "Chapter 2: no night is past the story")
	spawner.free()
	RunSession.forget_last_run()


func test_spawner_in_chapter_1() -> void:
	RunSession.reset(RunConfig.for_chapter(1))
	var spawner: MobSpawner = _spawner()
	check(not spawner.is_boss_night(3) and not spawner.is_boss_night(7), "Chapter 1 has no Moon-Eater night")
	check(not spawner.is_eyes_night(5), "Chapter 1 has no eyes")
	spawner.free()
	RunSession.forget_last_run()


func test_spawner_in_endless() -> void:
	RunSession.reset(RunConfig.for_endless())
	var spawner: MobSpawner = _spawner()
	check(not spawner.is_boss_night(7) and not spawner.is_eyes_night(5), "endless: no Moon-Eater and no eyes")
	check_eq(spawner.endless_nights_past(7), 0, "endless: night 7 is the story's last")
	check_eq(spawner.endless_nights_past(9), 2, "endless: night 9 is 2 past the story")
	check(spawner.hp_multiplier(9) > spawner.hp_multiplier(7), "endless: mobs on night 9 are tougher than on night 7")
	spawner.free()
	RunSession.forget_last_run()


func test_lantern_stages_per_chapter() -> void:
	var lantern: MoonLantern = MoonLantern.new()  # out of the tree: its stages only
	RunSession.reset(RunConfig.for_chapter(1))
	check_eq(lantern.max_stage(), 3, "Chapter 1's lantern has 3 stages")
	RunSession.reset(RunConfig.for_chapter(2))
	check_eq(lantern.max_stage(), 6, "Chapter 2's lantern has 6 stages")
	RunSession.reset(RunConfig.for_endless())
	check_eq(lantern.max_stage(), 6, "an endless run's lantern has Chapter 2's 6 stages")
	lantern.free()
	RunSession.forget_last_run()


func test_intro_plays_outside_endless() -> void:
	check(not GameManager.intro_pages(RunConfig.for_chapter(1)).is_empty(), "Chapter 1 opens with its intro")
	check(not GameManager.intro_pages(RunConfig.for_chapter(2)).is_empty(), "Chapter 2 opens with its intro")
	check(GameManager.intro_pages(RunConfig.for_endless()).is_empty(), "an endless run plays no intro")


## A spawner with a Moon-Eater set, as the world scene's has.
func _spawner() -> MobSpawner:
	var spawner: MobSpawner = MobSpawner.new()
	spawner.boss_definition = MobDefinition.new()
	return spawner
