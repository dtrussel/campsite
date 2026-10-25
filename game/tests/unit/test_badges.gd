extends "res://tests/unit/unit_test.gd"

## The badge rule: whether a badge is met, given plain facts (the run's
## stats, its chapter, whether it was won, the totals across runs, the
## heroes won with and the roster). No run is played.


func test_a_run_stat_badge_is_met_at_its_amount() -> void:
	var badge: BadgeDefinition = _badge(&"run_stat", &"torches_placed", 5)
	check(not Badges.is_met(badge, _facts({&"torches_placed": 4})), "4 torches this run is not 5")
	check(Badges.is_met(badge, _facts({&"torches_placed": 5})), "5 torches this run meets it")
	check(not Badges.is_met(badge, _facts({}, 1, false, {&"torches_placed": 50})),
		"a run-stat badge does not count other runs")


func test_a_total_badge_counts_every_run() -> void:
	var badge: BadgeDefinition = _badge(&"total", &"built", 50)
	check(not Badges.is_met(badge, _facts({}, 1, false, {&"built": 49})), "49 built in total is not 50")
	check(Badges.is_met(badge, _facts({}, 1, false, {&"built": 50})), "50 built in total meets it")
	check(not Badges.is_met(badge, _facts({&"built": 80})), "a total badge reads the totals, not this run")


func test_a_win_badge_needs_a_won_run() -> void:
	var badge: BadgeDefinition = _badge(&"win", &"", 1)
	check(not Badges.is_met(badge, _facts({}, 1, false)), "a lost run does not meet a win badge")
	check(Badges.is_met(badge, _facts({}, 1, true)), "a won Chapter 1 run meets it")
	check(Badges.is_met(badge, _facts({}, 2, true)), "a won Chapter 2 run meets it")


func test_a_chapter_win_badge_needs_that_chapter() -> void:
	var badge: BadgeDefinition = _badge(&"win", &"", 1, 2)
	check(not Badges.is_met(badge, _facts({}, 1, true)), "winning Chapter 1 is not winning Chapter 2")
	check(Badges.is_met(badge, _facts({}, 2, true)), "winning Chapter 2 meets it")
	check(not Badges.is_met(badge, _facts({}, 2, false)), "losing Chapter 2 does not")


func test_a_win_badge_with_a_stat_needs_the_stat_too() -> void:
	var badge: BadgeDefinition = _badge(&"win", &"fire_low_pct", 50)
	check(not Badges.is_met(badge, _facts({&"fire_low_pct": 49}, 1, true)), "a win with the fire under half is not enough")
	check(Badges.is_met(badge, _facts({&"fire_low_pct": 50}, 1, true)), "a win with the fire at half meets it")
	check(not Badges.is_met(badge, _facts({&"fire_low_pct": 100}, 1, false)), "a lost run with the fire full does not")


func test_a_win_each_hero_badge_needs_every_hero_in_the_roster() -> void:
	var badge: BadgeDefinition = _badge(&"win_each_hero", &"", 1)
	var roster: Array[StringName] = [&"leo", &"nela"]
	check(not Badges.is_met(badge, _facts({}, 1, true, {}, [&"leo"], roster)), "a win as Leo alone is not both heroes")
	check(Badges.is_met(badge, _facts({}, 1, false, {}, [&"leo", &"nela"], roster)),
		"wins as Leo and Nela meet it, whichever run ends")
	var bigger: Array[StringName] = [&"leo", &"nela", &"tess"]
	check(not Badges.is_met(badge, _facts({}, 1, true, {}, [&"leo", &"nela"], bigger)),
		"a third hero in the roster needs a win too")


func _badge(condition: StringName, stat: StringName, amount: int, chapter: int = 0) -> BadgeDefinition:
	var badge: BadgeDefinition = BadgeDefinition.new()
	badge.id = &"test_badge"
	badge.condition = condition
	badge.stat = stat
	badge.amount = amount
	badge.chapter = chapter
	return badge


func _facts(stats: Dictionary, chapter: int = 1, won: bool = false, totals: Dictionary = {},
		heroes_won: Array[StringName] = [], roster: Array[StringName] = [&"leo", &"nela"]) -> Badges.Facts:
	var facts: Badges.Facts = Badges.Facts.new()
	facts.stats = stats
	facts.chapter = chapter
	facts.won = won
	facts.totals = totals
	facts.heroes_won = heroes_won
	facts.roster = roster
	return facts
