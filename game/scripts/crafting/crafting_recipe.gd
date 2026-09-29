class_name CraftingRecipe
extends Resource

## CraftingRecipe
##
## Typed data for one recipe: consume `inputs`, produce `output_amount`
## of `output_id`. Stored as a .tres file under res://resources/recipes/.
## Loaded once at startup by CraftingManager.
##
## A recipe can instead have an `effect` on the camp (feature 017):
##   &"feed_fire"    - heals the campfire (only while it is damaged)
##   &"stone_hearth" - upgrades the campfire (once per run)
##   &"sturdy_stick" - Leo hits harder (once per run; feature 019)
##   &"slingshot"    - Nela attacks from further away (once per run)
##   &"trap_refill"  - every Snap Trap gets all its snaps back
## `station` is where it is made: the campfire, or a Crafting Table
## (which must be built first).
## Effect recipes may leave `output_id` empty; `icon_name` (an icon in
## res://assets/icons/) is shown as their result in the crafting panel.

const EFFECTS: Array[StringName] = [&"feed_fire", &"stone_hearth", &"sturdy_stick", &"slingshot", &"trap_refill"]
const STATION_CAMPFIRE: StringName = &"campfire"
const STATION_TABLE: StringName = &"table"

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var inputs: Dictionary = {}      # { &"wood": 1, &"resin": 1 }
@export var output_id: StringName = &""
@export var output_amount: int = 1
@export var effect: StringName = &""
@export var station: StringName = &"campfire"
@export var icon_name: String = ""
@export var xp_reward: int = 3
@export var sort_order: int = 100


func input_summary() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for key in inputs.keys():
		var def: ResourceDefinition = ResourceManager.get_definition(StringName(key))
		var label: String = def.display_name if def != null else String(key).capitalize()
		parts.append("%d %s" % [int(inputs[key]), label])
	return ", ".join(parts)


## The picture for the recipe's result: the output item's icon, or
## `icon_name` for effect recipes.
func result_icon() -> Texture2D:
	if icon_name != "":
		return Fx.icon(icon_name)
	var def: ResourceDefinition = ResourceManager.get_definition(output_id)
	return def.icon if def != null else null
