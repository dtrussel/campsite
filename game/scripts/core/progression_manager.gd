extends Node

## ProgressionManager
##
## Autoload that owns per-character XP and level state. Characters
## call register_character(self, stats) in _ready; callers (mob on
## kill, build manager on placement, resource node on gather, the
## time manager on dawn) call award_xp to credit progress.

signal xp_gained(character: Node, amount: int, source: StringName)
signal level_up(character: Node, new_level: int)

const SURVIVE_NIGHT_XP: int = 10

var _state: Dictionary = {}  # Node -> { level: int, xp: int, stats: CharacterStatsDefinition }


func _ready() -> void:
	if TimeManager and not TimeManager.dawn_started.is_connected(_on_dawn_started):
		TimeManager.dawn_started.connect(_on_dawn_started)


func register_character(character: Node, stats: CharacterStatsDefinition) -> void:
	if character == null:
		return
	if _state.has(character):
		return
	if stats == null:
		push_warning("ProgressionManager: '%s' registered without stats" % character.name)
	_state[character] = {
		"level": 1,
		"xp": 0,
		"stats": stats,
	}
	if not character.tree_exiting.is_connected(_on_character_exiting):
		character.tree_exiting.connect(_on_character_exiting.bind(character))


func unregister_character(character: Node) -> void:
	_state.erase(character)


func award_xp(character: Node, amount: int, source: StringName) -> void:
	if character == null or amount <= 0:
		return
	if not _state.has(character):
		return
	var entry: Dictionary = _state[character]
	entry["xp"] = int(entry["xp"]) + amount
	xp_gained.emit(character, amount, source)
	_check_level_ups(character, entry)


func get_level(character: Node) -> int:
	if not _state.has(character):
		return 1
	return int(_state[character]["level"])


func get_xp(character: Node) -> int:
	if not _state.has(character):
		return 0
	return int(_state[character]["xp"])


func get_xp_to_next_level(character: Node) -> int:
	if not _state.has(character):
		return 0
	var entry: Dictionary = _state[character]
	var stats: CharacterStatsDefinition = entry["stats"] as CharacterStatsDefinition
	if stats == null:
		return 0
	var level: int = int(entry["level"])
	if level >= stats.max_level():
		return 0
	return stats.xp_threshold_for_level(level + 1) - int(entry["xp"])


func get_stats(character: Node) -> CharacterStatsDefinition:
	if not _state.has(character):
		return null
	return _state[character]["stats"] as CharacterStatsDefinition


func _check_level_ups(character: Node, entry: Dictionary) -> void:
	var stats: CharacterStatsDefinition = entry["stats"] as CharacterStatsDefinition
	if stats == null:
		return
	while int(entry["level"]) < stats.max_level():
		var next_threshold: int = stats.xp_threshold_for_level(int(entry["level"]) + 1)
		if int(entry["xp"]) >= next_threshold:
			entry["level"] = int(entry["level"]) + 1
			level_up.emit(character, int(entry["level"]))
		else:
			break


func _on_dawn_started(_day_number: int) -> void:
	for character in _state.keys():
		if character == null or not is_instance_valid(character):
			continue
		award_xp(character, SURVIVE_NIGHT_XP, &"survive_night")


func _on_character_exiting(character: Node) -> void:
	unregister_character(character)
