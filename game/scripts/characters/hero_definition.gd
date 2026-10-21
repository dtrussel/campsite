class_name HeroDefinition
extends Resource

## HeroDefinition
##
## One playable hero (feature 034). A hero can fill either role: the
## player character (player_controller.gd) or the AI companion
## (companion_controller.gd). Both role shells read their body, stats
## and combat style from here, so a hero plays the same way in either
## role. Stored as a .tres under res://resources/heroes/ and listed by
## HeroRoster.

@export var id: StringName = &""
@export var display_name: String = ""
## One line for the hero select card.
@export var tagline: String = ""
@export var portrait: Texture2D
@export var ui_color: Color = Color(1, 0.93, 0.7, 1)

@export_group("Body")
@export var model_scene: PackedScene
@export var model_scale: float = 0.7
## CharacterVisual clips (logical state -> clip name).
@export var clips: Dictionary = {}
@export var reference_speed: float = 7.0
@export var step_distance: float = 1.1
@export var capsule_height: float = 1.2
@export var hurt_sfx: StringName = &"player_hurt"
## Model parts put away while a hand tool (the build hammer) is out.
@export var tool_hidden_parts: PackedStringArray = PackedStringArray()
## The model's body-and-clothes mesh, which the badge outfit tints
## colour (Cosmetics).
@export var outfit_mesh: String = ""

@export_group("Combat")
@export var stats: CharacterStatsDefinition
@export var move_speed: float = 4.0
@export var companion_move_speed: float = 3.9
@export var attack_range: float = 2.0
@export var companion_attack_range: float = 2.0
@export var attack_cooldown: float = 0.65
@export var companion_attack_cooldown: float = 0.75
## Ranged heroes fire a pebble (PebbleShot); the hit lands on impact.
@export var ranged: bool = false

@export_group("Signature")
## The hero's signature tool path (tool tiers), tier 1 first: each tier
## is made at the Crafting Table once the one before it is owned.
@export var signature_tiers: Array[ToolTier] = []

@export_group("Select screen")
## 1-3 pips per row on the hero card.
@export_range(1, 3) var rating_health: int = 2
@export_range(1, 3) var rating_power: int = 2
@export_range(1, 3) var rating_reach: int = 2


## How many tiers the hero's signature tool has.
func tier_count() -> int:
	return signature_tiers.size()


## Tier `n` of the signature tool (1 is the first craft), or null.
func tier(n: int) -> ToolTier:
	return signature_tiers[n - 1] if n >= 1 and n <= signature_tiers.size() else null


## The tier that `recipe_id` makes (1-based), or 0 if it is not one of
## this hero's tiers.
func tier_of_recipe(recipe_id: StringName) -> int:
	for i in signature_tiers.size():
		if signature_tiers[i] != null and signature_tiers[i].recipe == recipe_id:
			return i + 1
	return 0
