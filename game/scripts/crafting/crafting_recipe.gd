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
##   &"tool_tier"    - the next tier of a hero's signature tool (Leo's
##                     Sturdy Stick, then Ember Stick; Nela's Slingshot).
##                     The hero whose `signature_tiers` names this recipe
##                     gets it, once the tier before it is owned.
##   &"trap_refill"  - every Snap Trap gets all its snaps back
## `station` is where it is made: the campfire, or a Crafting Table
## (which must be built first).
## Effect recipes may leave `output_id` empty; `icon_name` (an icon in
## res://assets/icons/) is shown as their result in the crafting panel.

const EFFECT_TOOL_TIER: StringName = &"tool_tier"
const EFFECTS: Array[StringName] = [&"feed_fire", &"stone_hearth", EFFECT_TOOL_TIER, &"trap_refill"]
const STATION_CAMPFIRE: StringName = &"campfire"
const STATION_TABLE: StringName = &"table"

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var inputs: Dictionary = {}      # { &"wood": 2 }
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
