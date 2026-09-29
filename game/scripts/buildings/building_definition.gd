class_name BuildingDefinition
extends Resource

## BuildingDefinition
##
## Typed data for one placeable building (Wooden Fence, Watch Post, ...).
## Stored as a .tres file under res://resources/buildings/. Loaded once
## at startup by BuildManager.

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var cost: Dictionary = {}        # { &"wood": 2, &"fiber": 1 }
@export var max_hp: int = 50
@export var footprint_size: Vector3 = Vector3(1.0, 1.0, 1.0)
@export var ui_color: Color = Color.WHITE
@export var sort_order: int = 100        # lower comes first in the build menu
## Sound when placed (AudioLibrary id).
@export var place_sound: StringName = &"place"
## Picture for the build hint (number keys follow sort_order).
@export var icon: Texture2D = null


## Scenes are referenced by path (not PackedScene) because the scene
## itself embeds this definition; a direct reference would be cyclic
## and fail to load.
@export_file("*.tscn") var scene_path: String = ""

var _scene_cache: PackedScene = null


func get_scene() -> PackedScene:
	if _scene_cache == null and scene_path != "":
		_scene_cache = load(scene_path) as PackedScene
	return _scene_cache


func cost_summary() -> String:
	if cost.is_empty():
		return "free"
	var parts: PackedStringArray = PackedStringArray()
	for key in cost.keys():
		var amount: int = int(cost[key])
		var label: String = String(key).capitalize()
		var def: ResourceDefinition = null
		if ResourceManager:
			def = ResourceManager.get_definition(StringName(key))
		if def != null:
			label = def.display_name
		parts.append("%d %s" % [amount, label])
	return ", ".join(parts)
