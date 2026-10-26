extends "res://tests/unit/unit_test.gd"

## The kids' blinks (BlinkScheduler): the eyes shut briefly after a
## random wait in a set range, and now and then twice in quick
## succession (a double blink), never three times.

const STEP: float = 1.0 / 60.0


## Ticks `scheduler` for `seconds`; returns the times (s) the eyes shut.
func _shut_times(scheduler: BlinkScheduler, seconds: float) -> Array[float]:
	var times: Array[float] = []
	var shut: bool = false
	var t: float = 0.0
	while t < seconds:
		t += STEP
		var now: bool = scheduler.tick(STEP)
		if now and not shut:
			times.append(t)
		shut = now
	return times


func test_blinks_come_a_few_seconds_apart_or_as_a_quick_double() -> void:
	var doubles: int = 0
	var singles: int = 0
	var gaps: Dictionary = {}
	for seed in 20:
		var times: Array[float] = _shut_times(BlinkScheduler.new(seed), 120.0)
		check(times.size() >= 15, "seed %d: a face blinks often (%d in 2 min)" % [seed, times.size()])
		check(times[0] >= BlinkScheduler.GAP_MIN - STEP and times[0] <= BlinkScheduler.GAP_MAX + STEP,
			"seed %d: the first blink comes after %.2f s" % [seed, times[0]])
		var quick_run: int = 0
		for i in range(1, times.size()):
			var gap: float = times[i] - times[i - 1]
			var quick: bool = gap < BlinkScheduler.GAP_MIN * 0.5
			if quick:
				doubles += 1
				quick_run += 1
				check(gap <= BlinkScheduler.BLINK_SECONDS + BlinkScheduler.DOUBLE_GAP + 3 * STEP,
					"seed %d: a double blink's second comes right after (%.2f s)" % [seed, gap])
				check(quick_run == 1, "seed %d: never three blinks in a row" % seed)
			else:
				singles += 1
				quick_run = 0
				var after_shut: float = gap - BlinkScheduler.BLINK_SECONDS
				check(after_shut >= BlinkScheduler.GAP_MIN - 2 * STEP and after_shut <= BlinkScheduler.GAP_MAX + 2 * STEP,
					"seed %d: %.2f s open between blinks, within %.0f-%.0f s" % [seed, after_shut,
						BlinkScheduler.GAP_MIN, BlinkScheduler.GAP_MAX])
				gaps[snappedf(gap, 0.5)] = true
	check(doubles > 0 and doubles < singles, "sometimes a double blink (%d doubles, %d singles)" % [doubles, singles])
	check(gaps.size() >= 5, "the wait varies (%d different waits)" % gaps.size())


func test_a_blink_is_brief() -> void:
	var scheduler: BlinkScheduler = BlinkScheduler.new(4)
	var shut_frames: int = 0
	var longest: int = 0
	for i in int(60.0 / STEP):
		if scheduler.tick(STEP):
			shut_frames += 1
			longest = maxi(longest, shut_frames)
		else:
			shut_frames = 0
	check(longest * STEP <= BlinkScheduler.BLINK_SECONDS + 2 * STEP and longest > 0,
		"the eyes stay shut at most %.2f s (%.2f s)" % [BlinkScheduler.BLINK_SECONDS, longest * STEP])
