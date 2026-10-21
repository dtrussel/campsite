extends Node

## Badges
##
## The Camp Badges (journal badges 02): checks every BadgeDefinition
## (res://resources/badges/) live, whenever GameManager records a stat
## during play, and again at the end of a run, for the win badges. An
## earned badge is kept in the profile ("badges.<id>") for good, is
## earned only once, and is announced with a HUD toast.
##
## It also keeps what badges count across runs in the profile: the
## totals of the stats `total` badges count ("totals.<stat>", added to
## as they are recorded, so a run that is quit still counts) and the
## heroes a run has been won with ("heroes.won.<id>").

## A badge was earned just now (not one earned before).
signal badge_earned(badge: BadgeDefinition)

const BADGES_DIR: String = "res://resources/badges/"
const EARNED_PREFIX: String = "badges."
const TOTAL_PREFIX: String = "totals."
const HERO_WON_PREFIX: String = "heroes.won."

var _definitions: Array[BadgeDefinition] = []
## The stats some `total` badge counts.
var _total_stats: Dictionary = {}


func _ready() -> void:
	for res in DefinitionLoader.load_all(BADGES_DIR):
		var badge: BadgeDefinition = res as BadgeDefinition
		if badge != null:
			_definitions.append(badge)
			if badge.condition == &"total":
				_total_stats[badge.stat] = true
	_definitions.sort_custom(func(a: BadgeDefinition, b: BadgeDefinition) -> bool:
		return a.resource_path < b.resource_path)
	GameManager.stat_recorded.connect(_on_stat_recorded)
	GameManager.run_ended.connect(_on_run_ended)


## Every badge, in scrapbook order (by file name).
func definitions() -> Array[BadgeDefinition]:
	return _definitions


func get_badge(id: StringName) -> BadgeDefinition:
	for badge in _definitions:
		if badge.id == id:
			return badge
	return null


func has_badge(id: StringName) -> bool:
	return bool(Profile.get_value(EARNED_PREFIX + String(id), false))


## `stat` added up over every run, as the profile keeps it.
func total(stat: StringName) -> int:
	return int(Profile.get_value(TOTAL_PREFIX + String(stat), 0))


## Whether a run has been won playing `hero`.
func has_won_with(hero: StringName) -> bool:
	return bool(Profile.get_value(HERO_WON_PREFIX + String(hero), false))


## Awards every badge whose condition is met now and not earned before,
## and returns them. `run_won` is true at the end of a won run, when the
## win badges are checked too.
func check(run_won: bool = false) -> Array[BadgeDefinition]:
	var earned: Array[BadgeDefinition] = []
	for badge in _definitions:
		if not has_badge(badge.id) and _is_met(badge, run_won):
			_award(badge)
			earned.append(badge)
	return earned


func _is_met(badge: BadgeDefinition, run_won: bool) -> bool:
	match badge.condition:
		&"run_stat":
			return _run_stat(badge.stat) >= badge.amount
		&"total":
			return total(badge.stat) >= badge.amount
		&"win":
			return run_won and (badge.chapter == 0 or badge.chapter == GameManager.chapter()) \
				and (badge.stat == &"" or _run_stat(badge.stat) >= badge.amount)
		&"win_each_hero":
			for hero in HeroRoster.all():
				if not has_won_with(hero.id):
					return false
			return true
	return false


func _run_stat(stat: StringName) -> int:
	return int(GameManager.stats.get(stat, 0))


func _award(badge: BadgeDefinition) -> void:
	Profile.set_value(EARNED_PREFIX + String(badge.id), true)
	PlaytestLog.write("badge_earned id=%s day=%d" % [badge.id, TimeManager.day_number])
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", "Badge earned: %s!" % badge.display_name, badge.icon)
	badge_earned.emit(badge)


func _on_stat_recorded(stat: StringName, amount: int) -> void:
	# Only play counts: not a save being loaded, nor a menu or end screen.
	if not GameManager.is_playing() or RunSession.is_restoring():
		return
	if amount > 0 and _total_stats.has(stat):
		Profile.set_value(TOTAL_PREFIX + String(stat), total(stat) + amount)
	check()


func _on_run_ended(won: bool, _reason: String) -> void:
	if won:
		Profile.set_value(HERO_WON_PREFIX + String(GameManager.hero_id), true)
	check(won)
