class_name ToolTier
extends Resource

## ToolTier
##
## One step on a hero's signature tool path (tool tiers): Leo's Sturdy
## Stick (tier 1), then his Ember Stick (tier 2). A HeroDefinition lists
## its tiers in order in `signature_tiers`; each is made at the Crafting
## Table with `recipe` (a CraftingRecipe with the tool_tier effect), and
## only once the tier before it is owned.
##
## A hero who owns a tier owns every tier below it, so the bonuses add
## up: damage bonuses add, range factors multiply, and the effects of
## every owned tier apply.

## What an owned tier can add to the hero's hits and body:
##   &"burn"        - each hit sets the mob burning (Burn: 1 damage/s, 3 s)
##   &"night_light" - a small personal light at night (not near a torch)
##   &"double_shot" - every third shot fires two pebbles (Hero.DOUBLE_SHOT_EVERY)
const EFFECTS: Array[StringName] = [&"burn", &"night_light", &"double_shot"]

## The CraftingRecipe id that makes this tier.
@export var recipe: StringName = &""
@export var label: String = ""
## An icon in res://assets/icons/.
@export var icon: String = ""
@export var damage_bonus: int = 0
@export var range_factor: float = 1.0
@export var companion_range_factor: float = 1.0
@export var effects: Array[StringName] = []
