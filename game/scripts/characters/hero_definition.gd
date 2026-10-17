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

@export_group("Combat")
@export var stats: CharacterStatsDefinition
@export var move_speed: float = 5.0
@export var companion_move_speed: float = 4.8
@export var attack_range: float = 2.0
@export var companion_attack_range: float = 2.0
@export var attack_cooldown: float = 0.5
@export var companion_attack_cooldown: float = 0.6
## Ranged heroes fire a pebble (PebbleShot); the hit lands on impact.
@export var ranged: bool = false

@export_group("Signature")
## The Crafting Table recipe that upgrades this hero, once per run.
@export var signature_recipe: StringName = &""
@export var signature_label: String = ""
@export var signature_icon: String = ""
@export var signature_damage_bonus: int = 0
@export var signature_range_factor: float = 1.0
@export var companion_signature_range_factor: float = 1.0

@export_group("Select screen")
## 1-3 pips per row on the hero card.
@export_range(1, 3) var rating_health: int = 2
@export_range(1, 3) var rating_power: int = 2
@export_range(1, 3) var rating_reach: int = 2
