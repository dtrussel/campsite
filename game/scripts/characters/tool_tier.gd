class_name ToolTier
extends Resource

## ToolTier
##
## One step on a hero's signature tool path (tool tiers): Leo's Sturdy
## Stick (tier 1), then his Ember Stick (tier 2) and Blaze Stick (tier 3);
## Nela's Slingshot, Double Sling and Glow Sling. A HeroDefinition lists
## its tiers in order in `signature_tiers`; each is made at the Crafting
## Table with `recipe` (a CraftingRecipe with the tool_tier effect), and
## only once the tier before it is owned.
##
## A hero who owns a tier owns every tier below it, so the bonuses add
## up: damage bonuses add, range factors multiply, and the effects of
## every owned tier apply.

## What an owned tier can add to the hero's hits and body; each effect
## reads its numbers from the tier that lists it (the groups below):
##   &"burn"        - each hit sets the mob burning (Burn)
##   &"burn_splash" - a burning hit also sets the mobs right next to the
##                    target burning (burn_splash_radius)
##   &"night_light" - a small personal light at night (not near a torch)
##   &"bright_light" - that light reaches a little further (light_range)
##   &"double_shot" - every few shots fire two pebbles (double_shot_every)
##   &"pierce"      - a pebble flies on through its target to the next mob
##                    in its line (PebbleShot.pierce_target)
##   &"glow_hit"    - each hit briefly lights the mob (GlowMark)
const EFFECTS: Array[StringName] = [&"burn", &"burn_splash", &"night_light", &"bright_light", &"double_shot", &"pierce", &"glow_hit"]

## The CraftingRecipe id that makes this tier.
@export var recipe: StringName = &""
@export var label: String = ""
## An icon in res://assets/icons/.
@export var icon: String = ""
@export var damage_bonus: int = 0
@export var range_factor: float = 1.0
@export var companion_range_factor: float = 1.0
@export var effects: Array[StringName] = []

@export_group("Burn")
## `burn`: damage per tick, seconds between ticks, and ticks in all.
@export var burn_damage: int = 1
@export var burn_tick_seconds: float = 1.0
@export var burn_ticks: int = 3
## `burn_splash`: how close (flat metres) a mob must stand to a burning
## hit's target to catch the burn.
@export var burn_splash_radius: float = 1.6

@export_group("Light")
## `night_light` / `bright_light`: the personal light's reach in metres.
@export var light_range: float = 3.0

@export_group("Double shot")
## `double_shot`: every this-many-th shot fires a second pebble, this
## many seconds after the first.
@export var double_shot_every: int = 3
@export var double_shot_gap_seconds: float = 0.08

@export_group("Pierce")
## `pierce`: how far past its target (flat metres, along its line) a
## pebble flies on, and how far off that line a mob may stand.
@export var pierce_reach: float = 3.0
@export var pierce_width: float = 0.8

@export_group("Glow")
## `glow_hit`: how long the mob glows, the light's reach and brightness.
@export var glow_seconds: float = 1.5
@export var glow_range: float = 2.5
@export var glow_energy: float = 1.4


## How long a `burn` lasts: its ticks, one every burn_tick_seconds.
func burn_seconds() -> float:
	return burn_tick_seconds * burn_ticks


## What is wrong with the numbers this tier's effects use (for the
## validator); empty when they are sound.
func problems() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if effects.has(&"burn") and (burn_damage <= 0 or burn_ticks <= 0 or burn_tick_seconds <= 0.0):
		out.append("burns, but its burn_damage, burn_ticks and burn_tick_seconds must be positive")
	if effects.has(&"burn_splash") and burn_splash_radius <= 0.0:
		out.append("splashes its burn, but burn_splash_radius is not positive")
	if (effects.has(&"night_light") or effects.has(&"bright_light")) and light_range <= 0.0:
		out.append("gives a light, but light_range is not positive")
	if effects.has(&"double_shot") and (double_shot_every < 2 or double_shot_gap_seconds < 0.0):
		out.append("double-shoots, but double_shot_every must be 2 or more and the gap not negative")
	if effects.has(&"pierce") and (pierce_reach <= 0.0 or pierce_width <= 0.0):
		out.append("pierces, but pierce_reach and pierce_width must be positive")
	if effects.has(&"glow_hit") and (glow_seconds <= 0.0 or glow_range <= 0.0):
		out.append("glows, but glow_seconds and glow_range must be positive")
	return out
