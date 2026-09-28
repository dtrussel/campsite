class_name CompanionDefinition
extends Resource

## CompanionDefinition
##
## Typed data for one companion archetype (Sibling, Dog, ...). Stored
## as a .tres file under res://resources/companions/.

@export var id: StringName = &""
@export var display_name: String = ""
@export var move_speed: float = 4.5
@export var attack_damage: int = 3
@export var attack_range: float = 2.0
@export var attack_cooldown_seconds: float = 0.6
@export var ui_color: Color = Color(0.6, 0.85, 0.55, 1)


## Scenes are referenced by path (not PackedScene) because the scene
## itself embeds this definition; a direct reference would be cyclic
## and fail to load.
@export_file("*.tscn") var scene_path: String = ""

var _scene_cache: PackedScene = null


func get_scene() -> PackedScene:
	if _scene_cache == null and scene_path != "":
		_scene_cache = load(scene_path) as PackedScene
	return _scene_cache
