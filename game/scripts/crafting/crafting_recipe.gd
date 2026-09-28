class_name CraftingRecipe
extends Resource

## CraftingRecipe
##
## Typed data for one recipe: consume `inputs`, produce `output_amount`
## of `output_id`. Stored as a .tres file under res://resources/recipes/.
## Loaded once at startup by CraftingManager.

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var inputs: Dictionary = {}      # { &"wood": 1, &"resin": 1 }
@export var output_id: StringName = &""
@export var output_amount: int = 1
@export var xp_reward: int = 3
@export var sort_order: int = 100


func input_summary() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for key in inputs.keys():
		var def: ResourceDefinition = ResourceManager.get_definition(StringName(key))
		var label: String = def.display_name if def != null else String(key).capitalize()
		parts.append("%d %s" % [int(inputs[key]), label])
	return ", ".join(parts)
