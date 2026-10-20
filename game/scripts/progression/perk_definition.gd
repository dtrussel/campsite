class_name PerkDefinition
extends Resource

## PerkDefinition
##
## One perk card (perk cards, .scratch/perk-cards). On each level-up the
## player's hero picks 1 of 3 cards (PerkPicker); PerkManager keeps what
## each character has taken and answers the gameplay hooks. Stored as a
## .tres under res://resources/perks/, the same pattern as HeroDefinition.
##
## Effect kinds:
## - `stat_mult`: multiplies one named stat (`stat`) by `value`. Hooks ask
##   PerkManager.multiplier(character, stat), which is 1.0 without perks.
## - `flag`: switches a behaviour on. Hooks ask PerkManager.has_flag(
##   character, flag); `value` is the flag's number, if it needs one.
## - `on_hit`: changes what a hit does. Hooks ask
##   PerkManager.on_hit_perks(character, source) and read `value`,
##   `extra_targets` and `reach`.

const POOLS: Array[StringName] = [&"shared", &"leo", &"nela", &"sibling"]
const EFFECT_KINDS: Array[StringName] = [&"stat_mult", &"flag", &"on_hit"]
## Stats a `stat_mult` perk can scale. A hook reads each one; add the
## name here when you add its hook, so a typo in a .tres fails validation.
const STATS: Array[StringName] = [
	&"gather_time",  # resource_node.gd: seconds per gather
	&"attack_range",  # player_controller / companion_controller get_attack_range()
]
## Which hits an `on_hit` perk listens to.
const HIT_SOURCES: Array[StringName] = [&"any", &"melee", &"pebble"]

@export var id: StringName = &""
@export var display_name: String = ""
## One line on the card. "{hero}" and "{companion}" are filled in.
@export var description: String = ""
## An icon name under res://assets/icons/ (Fx.icon).
@export var icon: String = ""
## Who can be offered it: &"shared" (anyone), &"sibling" (anyone, about
## playing together), or a hero id (&"leo", &"nela") for that hero only.
@export var pool: StringName = &"shared"
@export var effect_kind: StringName = &"stat_mult"
## True if it can be taken again; each copy applies once more.
@export var stacks: bool = false

@export_group("Stat multiplier")
## One of STATS.
@export var stat: StringName = &""
## The multiplier (0.7 = 30% less, 1.2 = 20% more). Also the number a
## `flag` or `on_hit` perk carries (a damage factor, a heal share...).
@export var value: float = 1.0

@export_group("Flag")
## The switch a hook checks. Empty means the perk's id.
@export var flag: StringName = &""

@export_group("On hit")
## One of HIT_SOURCES.
@export var hit_source: StringName = &"any"
## Extra mobs the hit also reaches (a wider swing, a bounce).
@export var extra_targets: int = 0
## How far from the first target (m) those extra mobs can be.
@export var reach: float = 0.0


func flag_name() -> StringName:
	return flag if flag != &"" else id


## True if a character playing `hero_id` can be offered this card.
func is_for_hero(hero_id: StringName) -> bool:
	return pool == &"shared" or pool == &"sibling" or pool == hero_id


func icon_texture() -> Texture2D:
	return Fx.icon(icon)


## What is missing or wrong, for validate_project.gd. Empty when sound.
func problems() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if id == &"":
		out.append("has no id")
	if display_name.strip_edges() == "":
		out.append("has no name")
	if description.strip_edges() == "":
		out.append("has no line of text")
	if icon == "" or icon_texture() == null:
		out.append("has no icon ('%s')" % icon)
	if not POOLS.has(pool):
		out.append("has unknown pool '%s'" % pool)
	if not EFFECT_KINDS.has(effect_kind):
		out.append("has unknown effect kind '%s'" % effect_kind)
	match effect_kind:
		&"stat_mult":
			if not STATS.has(stat):
				out.append("scales unknown stat '%s'" % stat)
			if value <= 0.0 or is_equal_approx(value, 1.0):
				out.append("has a stat multiplier that does nothing (%s)" % value)
		&"on_hit":
			if not HIT_SOURCES.has(hit_source):
				out.append("has unknown hit source '%s'" % hit_source)
	return out
