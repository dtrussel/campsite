class_name MobDefinition
extends Resource

## Defines a mob type. Stored as a .tres file in resources/mobs/.

@export var id: String = ""
@export var display_name: String = ""
@export var scene: PackedScene
@export var max_health: int = 30
@export var move_speed: float = 3.5
@export var attack_power: int = 5
@export var attack_rate: float = 1.5         # seconds between attacks
@export var xp_reward: int = 10
@export var loot_table: Dictionary = {}       # {resource_id: drop_chance 0.0-1.0}
@export var target_priority: Array[String] = ["building", "base", "player", "companion"]
