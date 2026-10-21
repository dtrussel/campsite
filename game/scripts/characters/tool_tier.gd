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

## What an owned tier can add to the hero's hits and body:
##   &"burn"        - each hit sets the mob burning (Burn: 1 damage/s, 3 s)
##   &"burn_splash" - a burning hit also sets the mobs right next to the
##                    target burning (Burn.SPLASH_RADIUS)
##   &"night_light" - a small personal light at night (not near a torch)
##   &"bright_light" - that light reaches a little further
##   &"double_shot" - every third shot fires two pebbles (Hero.DOUBLE_SHOT_EVERY)
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
