class_name BuildingDefinition
extends Resource

## Defines a placeable building type. Stored as a .tres file in resources/buildings/.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var scene: PackedScene
@export var cost: Dictionary = {}        # {resource_id: amount}
@export var max_health: int = 100
@export var build_time_seconds: float = 2.0
@export var is_unique: bool = false      # only one instance allowed if true
