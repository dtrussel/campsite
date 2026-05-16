class_name CharacterStatsDefinition
extends Resource

## Defines base stats for a character type. Stored as a .tres file.

@export var character_id: String = ""
@export var display_name: String = ""
@export var base_health: int = 80
@export var base_stamina: int = 100
@export var base_courage: int = 10
@export var base_build_speed: float = 1.0
@export var base_gather_speed: float = 1.0
@export var base_attack_power: int = 8
@export var base_crafting_skill: int = 1
@export var xp_thresholds: Array[int] = [0, 100, 250, 500, 900]
