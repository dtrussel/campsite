class_name CraftingTable
extends Building

## CraftingTable
##
## A workbench (feature 019). While one stands in the camp, the recipes
## marked `requires_table` can be made, and the crafting panel also
## opens next to it (not only at the campfire).

const GROUP: StringName = &"crafting_table"


func _ready() -> void:
	super()
	if not has_meta(&"build_ghost"):
		add_to_group(GROUP)
