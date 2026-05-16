class_name CraftingRecipe
extends Resource

## Defines one crafting recipe. Stored as a .tres file.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var ingredients: Dictionary = {}   # {resource_id: amount}
@export var output_building: BuildingDefinition
@export var output_item_id: String = ""    # future: item system
@export var xp_reward: int = 5
@export var requires_crafting_table: bool = false
