class_name MobDefinition
extends Resource

## MobDefinition
##
## Typed data for one mob species (Shadow Imp, Bramble Beast, ...).
## Stored as a .tres file under res://resources/mobs/.

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_hp: int = 6
@export var move_speed: float = 2.2
@export var attack_damage: int = 3
@export var attack_range: float = 1.2
## Characters (boy, companions) closer than this get chased instead
## of the campfire.
@export var aggro_radius: float = 4.0
@export var attack_cooldown_seconds: float = 1.0
@export var xp_reward: int = 5
@export var ui_color: Color = Color(0.6, 0.4, 0.7, 1)


## Scenes are referenced by path (not PackedScene) because the scene
## itself embeds this definition; a direct reference would be cyclic
## and fail to load.
@export_file("*.tscn") var scene_path: String = ""

var _scene_cache: PackedScene = null


func get_scene() -> PackedScene:
	if _scene_cache == null and scene_path != "":
		_scene_cache = load(scene_path) as PackedScene
	return _scene_cache
