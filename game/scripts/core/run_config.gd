class_name RunConfig
extends RefCounted

## RunConfig
##
## What a run starts from (run lifecycle): the party, the chapter goal,
## endless mode, the seeds of the perk deal and the loot rolls, and the perk picker's
## auto-pick time. RunSession.start applies it; the same config plays
## the same deals and drops, so a test or a bug report can replay a run.

## Real seconds the perk picker waits before it takes the first card
## itself, in a normal game.
const DEFAULT_AUTO_PICK_SECONDS: float = 10.0
## The chance a run has a day chest (journal badges 04).
const DAY_CHEST_CHANCE: float = 0.5

## The played hero and the companion (HeroRoster ids). An empty or
## unknown companion falls back to the hero's default one.
var hero_id: StringName = &"leo"
var companion_id: StringName = &"nela"
## The chapter goal: nights to survive (3 is Chapter 1, 7 is Chapter 2).
var nights_to_win: int = 3
## Endless mode: a Chapter 2 run (nights_to_win 7) with no win and no
## Moon-Eater (GameManager.endless).
var endless: bool = false
## Seeds PerkManager.rng, which deals the perk cards.
var perk_seed: int = randi()
## Seeds GameManager.loot_rng, which rolls the shard drops.
var loot_seed: int = randi()
## Real seconds the perk picker waits before it auto-picks; 0 (or less)
## skips the picker and takes the first card at once.
var perk_auto_pick_seconds: float = DEFAULT_AUTO_PICK_SECONDS
## A perk card the played hero starts the run with (journal badges 06),
## or &"" for none. Given only if a badge has unlocked it.
var starting_perk: StringName = &""
## The day a day chest appears at the map edge (journal badges 04), or
## 0 for a run with none. current() rolls it: half the runs get one, on
## one of their days.
var day_chest_day: int = 0


## A config for the next run: the party, run length and endless flag
## GameManager holds
## (kept between runs), fresh seeds and the normal auto-pick time.
static func current() -> RunConfig:
	var config: RunConfig = RunConfig.new()
	config.hero_id = GameManager.hero_id
	config.companion_id = GameManager.companion_id
	config.nights_to_win = GameManager.nights_to_win
	config.endless = GameManager.endless
	config.starting_perk = StartingPerks.chosen()
	config.day_chest_day = roll_day_chest(config.nights_to_win)
	return config


## A day chest's day for a run of `days` days: one of them, or 0 (none)
## half the time.
static func roll_day_chest(days: int) -> int:
	if randf() >= DAY_CHEST_CHANCE:
		return 0
	return randi_range(1, maxi(days, 1))
