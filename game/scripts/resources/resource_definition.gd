class_name ResourceDefinition
extends Resource

## ResourceDefinition
##
## Typed data for one gatherable/spendable resource (Wood, Stone,
## Berries, ...). Stored as a .tres file under res://resources/items/.
## Loaded once at startup by ResourceManager.

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null
@export_range(1, 5) var rarity: int = 1
@export var max_stack: int = 99
@export var ui_color: Color = Color.WHITE
