extends "res://tests/unit/unit_test.gd"

## The idle fidgets' "now and then" (FidgetScheduler): a hero standing
## idle plays a fidget after a random wait in a set range, never the
## same fidget twice in a row, and only while idle.

const FIDGETS: Array[StringName] = [&"fidget_look", &"fidget_scratch", &"fidget_stretch"]
const STEP: float = 1.0 / 60.0


## Ticks `scheduler` idle until it picks a fidget; returns [the seconds
## waited, the fidget] (&"" if none within `limit` seconds).
func _wait_for_fidget(scheduler: FidgetScheduler, limit: float = 60.0) -> Array:
	var waited: float = 0.0
	while waited < limit:
		waited += STEP
		var fidget: StringName = scheduler.tick(STEP, true)
		if fidget != &"":
			return [waited, fidget]
	return [waited, &""]


func test_an_idle_hero_fidgets_after_a_wait_in_the_set_range() -> void:
	var waits: Dictionary = {}
	for seed in 40:
		var scheduler: FidgetScheduler = FidgetScheduler.new(FIDGETS, seed)
		var got: Array = _wait_for_fidget(scheduler)
		check(got[1] != &"", "seed %d: a fidget comes" % seed)
		check(got[0] >= FidgetScheduler.GAP_MIN - STEP and got[0] <= FidgetScheduler.GAP_MAX + STEP,
			"seed %d: after %.2f s, within %.0f-%.0f s" % [seed, got[0], FidgetScheduler.GAP_MIN, FidgetScheduler.GAP_MAX])
		waits[snappedf(got[0], 0.5)] = true
	check(waits.size() >= 5, "the wait varies (%d different waits over 40 heroes)" % waits.size())


func test_the_range_is_a_few_seconds_apart() -> void:
	check(FidgetScheduler.GAP_MIN >= 4.0 and FidgetScheduler.GAP_MAX <= 20.0 and FidgetScheduler.GAP_MAX > FidgetScheduler.GAP_MIN,
		"fidgets come now and then: every %.0f-%.0f s" % [FidgetScheduler.GAP_MIN, FidgetScheduler.GAP_MAX])


func test_no_fidget_plays_twice_in_a_row() -> void:
	for seed in 10:
		var scheduler: FidgetScheduler = FidgetScheduler.new(FIDGETS, seed)
		var last: StringName = &""
		var repeats: int = 0
		var seen: Dictionary = {}
		for i in 30:
			var fidget: StringName = _wait_for_fidget(scheduler)[1]
			if fidget == last:
				repeats += 1
			last = fidget
			seen[fidget] = true
		check(repeats == 0, "seed %d: 30 fidgets, none the same as the one before (%d repeats)" % [seed, repeats])
		check(seen.size() == FIDGETS.size(), "seed %d: every fidget comes up" % seed)


func test_a_hero_with_one_fidget_plays_it_each_time() -> void:
	var scheduler: FidgetScheduler = FidgetScheduler.new([&"fidget_look"] as Array[StringName], 3)
	check(_wait_for_fidget(scheduler)[1] == &"fidget_look" and _wait_for_fidget(scheduler)[1] == &"fidget_look",
		"with only one fidget, it repeats")


func test_a_hero_with_no_fidgets_never_fidgets() -> void:
	var scheduler: FidgetScheduler = FidgetScheduler.new([] as Array[StringName], 3)
	check(_wait_for_fidget(scheduler)[1] == &"", "no fidgets listed: none in a minute")


func test_a_hero_that_is_not_idle_never_fidgets() -> void:
	var scheduler: FidgetScheduler = FidgetScheduler.new(FIDGETS, 5)
	var fired: int = 0
	for i in int(60.0 / STEP):
		if scheduler.tick(STEP, false) != &"":
			fired += 1
	check(fired == 0, "a minute moving, in an action or down: no fidget (%d)" % fired)


func test_the_wait_starts_again_each_time_the_hero_stops() -> void:
	for seed in 10:
		var scheduler: FidgetScheduler = FidgetScheduler.new(FIDGETS, seed)
		# Idle for most of the shortest wait, then busy a moment.
		var fired: bool = false
		for i in int((FidgetScheduler.GAP_MIN - 0.5) / STEP):
			fired = fired or scheduler.tick(STEP, true) != &""
		scheduler.tick(STEP, false)
		var got: Array = _wait_for_fidget(scheduler)
		check(not fired and got[0] >= FidgetScheduler.GAP_MIN - STEP,
			"seed %d: after a break the hero waits a full %.0f s or more again (%.2f s)" % [seed, FidgetScheduler.GAP_MIN, got[0]])
