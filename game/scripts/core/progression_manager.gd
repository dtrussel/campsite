extends Node

## Tracks XP and levels for all characters by string ID.

signal xp_gained(character_id: String, amount: int, new_total: int)
signal level_up(character_id: String, new_level: int)

const XP_THRESHOLDS: Array[int] = [0, 100, 250, 500, 900, 1400]
const MAX_LEVEL: int = 5

var _xp: Dictionary = {}    # character_id -> int
var _levels: Dictionary = {} # character_id -> int

func _ensure(character_id: String) -> void:
	if not _xp.has(character_id):
		_xp[character_id] = 0
		_levels[character_id] = 1

func award_xp(character_id: String, amount: int) -> void:
	_ensure(character_id)
	_xp[character_id] += amount
	xp_gained.emit(character_id, amount, _xp[character_id])
	_check_level_up(character_id)

func _check_level_up(character_id: String) -> void:
	var current_level: int = _levels[character_id]
	if current_level >= MAX_LEVEL:
		return
	var next_threshold: int = XP_THRESHOLDS[current_level]  # index = next level - 1
	if _xp[character_id] >= next_threshold:
		_levels[character_id] += 1
		level_up.emit(character_id, _levels[character_id])
		# Check again in case of multiple level-ups from a large XP grant
		if _levels[character_id] < MAX_LEVEL:
			_check_level_up(character_id)

func get_level(character_id: String) -> int:
	_ensure(character_id)
	return _levels[character_id]

func get_xp(character_id: String) -> int:
	_ensure(character_id)
	return _xp[character_id]

func get_xp_to_next_level(character_id: String) -> int:
	_ensure(character_id)
	var current_level: int = _levels[character_id]
	if current_level >= MAX_LEVEL:
		return 0
	return XP_THRESHOLDS[current_level] - _xp[character_id]

func get_level_for_xp(total_xp: int) -> int:
	var level: int = 1
	for i in range(1, XP_THRESHOLDS.size()):
		if total_xp >= XP_THRESHOLDS[i]:
			level = i + 1
		else:
			break
	return mini(level, MAX_LEVEL)
