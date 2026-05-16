class_name ResourceDefinition
extends Resource

## Defines a single resource type. Stored as a .tres file in resources/game_data/.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export_enum("Common", "Uncommon", "Rare") var rarity: int = 0
@export var max_stack: int = 999
