class_name BadgeDefinition
extends Resource

## BadgeDefinition
##
## One Camp Badge: a Scout-
## style milestone the profile keeps for good. Stored as a .tres under
## res://resources/badges/; Badges.is_met checks one against its facts,
## and the profile keeps the earned ones.
##
## Conditions:
## - `run_stat`: this run's `stat` (GameManager.stats) reaches `amount`.
##   Checked live.
## - `total`: `stat` added up over every run reaches `amount`. The
##   profile keeps the total (Profile.stat_total). Checked live.
## - `win`: a run is won; of `chapter` when it is above 0, and with this
##   run's `stat` at `amount` or more when `stat` is set (Fire Keeper:
##   the fire's lowest HP never under 50%). Checked at the end of a run.
## - `win_each_hero`: a run has been won playing each hero in the
##   roster. Checked at the end of a run.

const CONDITIONS: Array[StringName] = [&"run_stat", &"total", &"win", &"win_each_hero"]
## The run stats a badge can count (GameManager.stats). Add the name
## here when a badge needs a new one, so a typo in a .tres fails
## validation.
const STATS: Array[StringName] = [
	&"nights_survived", &"kills", &"gathered", &"built", &"crafted",
	&"torches_placed", &"repairs", &"shards", &"trap_snaps",
	&"gremlins_caught",  # mob_controller.gd: a Mushroom Gremlin caught
	&"fire_low_pct",  # game_manager.gd: the fire's lowest HP this run, in %
	&"lantern_lit",  # moon_lantern.gd: 1 once the Moon Lantern is full
]

@export var id: StringName = &""
@export var display_name: String = ""
## How to earn it, shown under a locked badge in the scrapbook.
@export_multiline var how_to_earn: String = ""
## An icon name under res://assets/icons/ (Fx.icon).
@export var icon: String = ""
## One of CONDITIONS.
@export var condition: StringName = &"run_stat"
## One of STATS (empty for a plain win or win_each_hero).
@export var stat: StringName = &""
@export var amount: int = 1
## For `win`: the chapter to win, or 0 for any.
@export var chapter: int = 0


func icon_texture() -> Texture2D:
	return Fx.icon(icon)


## What is missing or wrong, for validate_project.gd. Empty when sound.
func problems() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if id == &"":
		out.append("has no id")
	if display_name.strip_edges() == "":
		out.append("has no name")
	if how_to_earn.strip_edges() == "":
		out.append("has no how-to-earn text")
	if icon == "" or icon_texture() == null:
		out.append("has no icon ('%s')" % icon)
	if not CONDITIONS.has(condition):
		out.append("has unknown condition '%s'" % condition)
	var needs_stat: bool = condition == &"run_stat" or condition == &"total"
	if (needs_stat or stat != &"") and not STATS.has(stat):
		out.append("counts unknown stat '%s'" % stat)
	if (needs_stat or stat != &"") and amount <= 0:
		out.append("needs a positive amount (%d)" % amount)
	if chapter < 0 or chapter > 2:
		out.append("names unknown chapter %d" % chapter)
	return out
