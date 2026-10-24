class_name Badges
extends RefCounted

## Badges
##
## The Camp Badges: every BadgeDefinition under res://resources/badges/
## and the one rule of whether a badge is met, given the facts it reads
## (Facts). The profile is the one place a badge is earned: it builds
## the facts when a stat is recorded during play and when a run ends,
## keeps the earned badges for good and announces each with
## Profile.badge_earned (the HUD shows a toast, the end screen lists the
## run's badges).

const BADGES_DIR: String = "res://resources/badges/"

static var _definitions: Array[BadgeDefinition] = []


## Every badge, in scrapbook order (by file name).
static func definitions() -> Array[BadgeDefinition]:
	if _definitions.is_empty():
		for res in DefinitionLoader.load_all(BADGES_DIR):
			if res is BadgeDefinition:
				_definitions.append(res as BadgeDefinition)
		_definitions.sort_custom(func(a: BadgeDefinition, b: BadgeDefinition) -> bool:
			return a.resource_path < b.resource_path)
	return _definitions


static func get_badge(id: StringName) -> BadgeDefinition:
	for badge in definitions():
		if badge.id == id:
			return badge
	return null


## The stats some `total` badge counts across runs.
static func total_stats() -> Array[StringName]:
	var out: Array[StringName] = []
	for badge in definitions():
		if badge.condition == &"total" and not out.has(badge.stat):
			out.append(badge.stat)
	return out


## Whether `badge`'s condition holds for `facts`.
static func is_met(badge: BadgeDefinition, facts: Facts) -> bool:
	match badge.condition:
		&"run_stat":
			return int(facts.stats.get(badge.stat, 0)) >= badge.amount
		&"total":
			return int(facts.totals.get(badge.stat, 0)) >= badge.amount
		&"win":
			return facts.won and (badge.chapter == 0 or badge.chapter == facts.chapter) \
				and (badge.stat == &"" or int(facts.stats.get(badge.stat, 0)) >= badge.amount)
		&"win_each_hero":
			for hero in facts.roster:
				if not facts.heroes_won.has(hero):
					return false
			return true
	return false


## What a badge's condition reads: the run's own stats and chapter,
## whether it was won (false during play), the totals across runs and
## the heroes won with, and the heroes in the roster.
class Facts:
	extends RefCounted

	## The run's stats (stat -> count), as GameManager.stats.
	var stats: Dictionary = {}
	var chapter: int = 1
	var won: bool = false
	## Each counted stat added up over every run (stat -> count).
	var totals: Dictionary = {}
	var heroes_won: Array[StringName] = []
	var roster: Array[StringName] = []
