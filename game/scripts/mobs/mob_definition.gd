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
## Siege mobs (Bramble Beast) walk to the nearest building and tear it
## down before going for the campfire; they only turn on characters who
## come within aggro_radius.
@export var prefers_buildings: bool = false
## Attack damage multiplier against buildings (not the campfire).
@export var building_damage_multiplier: float = 1.0
## Seconds from the start of the attack clip to the moment it lands
## (feature 026). 0 = damage on the first frame (imps, gremlins). With a
## delay, the attack is telegraphed: kids who step out of reach during
## the windup are not hit (buildings and the campfire always are).
@export var attack_hit_delay: float = 0.0
## Burst (and sound) at the impact point of a delayed attack, plus a
## little camera shake. Empty = none.
@export var impact_burst: StringName = &""
## How far hits push this mob back (0 = immovable, 1 = an imp).
@export var knockback_scale: float = 1.0
## Thieves (Mushroom Gremlin, feature 021) ignore everyone, run to the
## camp's stash (a Storage Crate, else the campfire), grab up to
## `steal_amount` of the most plentiful resource and run back to the
## forest. Caught, they drop the loot; escaped, it is gone.
@export var steals_resources: bool = false
@export var steal_amount: int = 4
## Fx.burst kinds (and sounds) for rising out of the ground and dying.
@export var spawn_burst: StringName = &"shadow_spawn"
@export var death_burst: StringName = &"shadow_death"
## Loot: every `drop_every_n_kills`-th kill of this mob type (counted
## per run) leaves a `drop_item` pickup (Glow Shards for imps). 0 = never.
@export var drop_item: StringName = &""
@export var drop_every_n_kills: int = 0
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
