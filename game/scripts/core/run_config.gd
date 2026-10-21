class_name RunConfig
extends RefCounted

## RunConfig
##
## What a run starts from (run lifecycle): the party, the chapter goal,
## the seeds of the perk deal and the loot rolls, and the perk picker's
## auto-pick time. RunSession.start applies it; the same config plays
## the same deals and drops, so a test or a bug report can replay a run.

## Real seconds the perk picker waits before it takes the first card
## itself, in a normal game.
const DEFAULT_AUTO_PICK_SECONDS: float = 10.0

## The played hero and the companion (HeroRoster ids). An empty or
## unknown companion falls back to the hero's default one.
var hero_id: StringName = &"leo"
var companion_id: StringName = &"nela"
## The chapter goal: nights to survive (3 is Chapter 1, 7 is Chapter 2).
var nights_to_win: int = 3
## Seeds PerkManager.rng, which deals the perk cards.
var perk_seed: int = randi()
## Seeds GameManager.loot_rng, which rolls the shard drops.
var loot_seed: int = randi()
## Real seconds the perk picker waits before it auto-picks; 0 (or less)
## skips the picker and takes the first card at once.
var perk_auto_pick_seconds: float = DEFAULT_AUTO_PICK_SECONDS


## A config for the next run: the party and run length GameManager holds
## (kept between runs), fresh seeds and the normal auto-pick time.
static func current() -> RunConfig:
	var config: RunConfig = RunConfig.new()
	config.hero_id = GameManager.hero_id
	config.companion_id = GameManager.companion_id
	config.nights_to_win = GameManager.nights_to_win
	return config
