class_name CharacterStatsDefinition
extends Resource

## CharacterStatsDefinition
##
## Progression curve for one character archetype (player, Sibling,
## Dog, ...). Holds the XP threshold table and per-level stat bumps.
## Stored as a .tres file under res://resources/progression/.

@export var display_name: String = ""
@export var base_max_health: int = 50
@export var base_attack_damage: int = 4
@export var max_health_per_level: int = 5
@export var attack_damage_per_level: int = 1
## Cumulative XP needed to reach each level. Index 0 is level 1
## (always 0). Index N is the XP threshold for level N+1.
@export var xp_table: PackedInt32Array = PackedInt32Array(
	[0, 30, 75, 140, 225, 330, 460, 615, 800]
)
@export var ui_color: Color = Color.WHITE


func max_level() -> int:
	return xp_table.size()


func xp_threshold_for_level(level: int) -> int:
	if level <= 0:
		return 0
	if level > xp_table.size():
		return xp_table[xp_table.size() - 1]
	return xp_table[level - 1]
