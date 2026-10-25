class_name RunConfig
extends RefCounted

## RunConfig
##
## What a run starts from (run lifecycle): the party, the chapter (or an
## endless run), the nights to win, the seeds of the perk deal, the loot
## rolls and the day chest, and the perk picker's auto-pick time.
## RunSession holds it for the run in play, and it never changes once
## the run has started; the same config plays the same deals, drops and
## chest, so a test or a bug report can replay a run.
##
## It also answers the run's rules: which night is the Moon-Eater's,
## which dawn wins, how far an endless run is past the story, whether
## the Moon Lantern starts full and whether the chapter intro plays.

## The nights to win of each story chapter.
const CHAPTER_NIGHTS: Dictionary = {1: 3, 2: 7}

## Real seconds the perk picker waits before it takes the first card
## itself, in a normal game.
const DEFAULT_AUTO_PICK_SECONDS: float = 10.0
## The chance a config built for a chapter, or by Again, rolls a day
## chest.
const DAY_CHEST_CHANCE: float = 0.5

## The played hero and the companion (HeroRoster ids); set_party keeps
## them to known heroes.
var hero_id: StringName = &"leo"
var companion_id: StringName = &"nela"
## The story chapter: 1 "The Dark Moon" or 2 "Into the Hollow".
var chapter: int = 1
## Endless mode: a Chapter 2 run with no win and no Moon-Eater.
var endless: bool = false
## The nights to survive: the chapter's (CHAPTER_NIGHTS) when built
## for_chapter, though any count can be set (the balance sim does).
var nights_to_win: int = 3
## Seeds PerkManager.rng, which deals the perk cards.
var perk_seed: int = randi()
## Seeds GameManager.loot_rng, which rolls the shard drops.
var loot_seed: int = randi()
## Real seconds the perk picker waits before it auto-picks; 0 (or less)
## skips the picker and takes the first card at once.
var perk_auto_pick_seconds: float = DEFAULT_AUTO_PICK_SECONDS
## A perk card the played hero starts the run with,
## or &"" for none. Given only if a badge has unlocked it.
var starting_perk: StringName = &""
## Seeds the day chest's roll (roll_day_chest).
var chest_seed: int = randi()
## The day a day chest appears at the map edge, or
## 0 for a run with none. Rolled from chest_seed when a config is
## built: half the runs get one, on one of their days.
var day_chest_day: int = 0


## A config for a story chapter, with its nights to win, fresh seeds,
## its day chest rolled and the normal auto-pick time. The party is
## added at hero select.
static func for_chapter(number: int) -> RunConfig:
	var config: RunConfig = RunConfig.new()
	config.chapter = number
	config.nights_to_win = int(CHAPTER_NIGHTS.get(number, CHAPTER_NIGHTS[1]))
	config.day_chest_day = config.roll_day_chest(DAY_CHEST_CHANCE)
	return config


## A config for an endless run: Chapter 2 (its nights and moon rows)
## with the endless flag.
static func for_endless() -> RunConfig:
	var config: RunConfig = for_chapter(2)
	config.endless = true
	return config


## Whether the run has a Moon-Eater at all: Chapter 2, not endless.
func has_moon_eater() -> bool:
	return chapter == 2 and not endless


## Whether `night` is the Moon-Eater's: Chapter 2's last night.
func is_moon_eater_night(night: int) -> bool:
	return has_moon_eater() and night == nights_to_win


## Whether the dawn after `night` wins the run: any dawn at or past the
## nights to win, never in an endless run.
func dawn_wins(night: int) -> bool:
	return not endless and night >= nights_to_win


## How many nights `night` is past the story's last (0 outside an
## endless run, and on the story's nights).
func nights_past_story(night: int) -> int:
	return maxi(0, night - nights_to_win) if endless else 0


## Whether the Moon Lantern starts fully lit: in an endless run, so its
## shards go to Glow Lanterns and tool tiers.
func lantern_starts_full() -> bool:
	return endless


## Whether the chapter intro plays: never in an endless run, which comes
## after the story.
func plays_intro() -> bool:
	return not endless


## Again: a copy of this config for the next try, with the same
## chapter, mode, nights to win, party, starting perk and auto-pick
## time, plus fresh seeds and a fresh day chest roll.
func again() -> RunConfig:
	var config: RunConfig = RunConfig.new()
	config.hero_id = hero_id
	config.companion_id = companion_id
	config.chapter = chapter
	config.endless = endless
	config.nights_to_win = nights_to_win
	config.perk_auto_pick_seconds = perk_auto_pick_seconds
	config.starting_perk = starting_perk
	config.day_chest_day = config.roll_day_chest(DAY_CHEST_CHANCE)
	return config


## Takes `other`'s seeds (the perk deal, loot rolls and day chest) and
## its auto-pick time, keeping this config's shape and party.
func take_seeds_of(other: RunConfig) -> void:
	perk_seed = other.perk_seed
	loot_seed = other.loot_seed
	chest_seed = other.chest_seed
	perk_auto_pick_seconds = other.perk_auto_pick_seconds


## Sets the party (hero select does, on a draft config); an unknown
## hero is Leo, and an empty, unknown or same-as-the-hero companion is
## the hero's default one.
func set_party(hero_pick: StringName, companion_pick: StringName = &"") -> void:
	hero_id = hero_pick if HeroRoster.has_hero(hero_pick) else &"leo"
	if companion_pick == &"" or companion_pick == hero_id or not HeroRoster.has_hero(companion_pick):
		companion_pick = HeroRoster.default_companion(hero_id)
	companion_id = companion_pick


## The played hero's definition.
func hero() -> HeroDefinition:
	return HeroRoster.get_hero(hero_id)


## The companion's definition.
func companion() -> HeroDefinition:
	return HeroRoster.get_hero(companion_id)


## Writes the config into the save `data`, under the save's run keys:
## the chapter, the run length, the endless flag, the party and the day
## chest's day. The seeds and test settings are not saved: a continued
## run gets fresh ones.
func write_save(data: Dictionary) -> void:
	data["chapter"] = chapter
	data["nights_to_win"] = nights_to_win
	data["endless"] = endless
	data["party"] = {"hero": String(hero_id), "companion": String(companion_id)}
	data["day_chest_day"] = day_chest_day


## The config a save `data` was made with, with fresh seeds. Missing
## keys are what older saves meant: no endless flag is a story run, no
## party is Leo with Nela, no day chest's day is none, and no chapter
## (saves from before it was stored) is read from the run length, 7 or
## more nights being Chapter 2.
static func from_save(data: Dictionary) -> RunConfig:
	var config: RunConfig = RunConfig.new()
	config.nights_to_win = int(data.get("nights_to_win", CHAPTER_NIGHTS[1]))
	config.endless = bool(data.get("endless", false))
	if data.has("chapter"):
		config.chapter = int(data["chapter"])
	else:
		config.chapter = 2 if config.nights_to_win >= CHAPTER_NIGHTS[2] else 1
	var party: Dictionary = GameManager.party_of(data)
	config.set_party(party["hero"], party["companion"])
	config.day_chest_day = int(data.get("day_chest_day", 0))
	return config


## The day chest's day this config's chest_seed rolls: with `chance`,
## one of the run's days, else 0 (none). The same seed always rolls the
## same day.
func roll_day_chest(chance: float) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = chest_seed
	if rng.randf() >= chance:
		return 0
	return rng.randi_range(1, maxi(nights_to_win, 1))
