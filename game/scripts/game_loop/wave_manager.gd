extends Node

## Spawns mob waves at night. Stub for Phase 5 — currently logs only.

signal wave_started(wave_number: int, mob_count: int)
signal wave_ended(wave_number: int)
signal mob_spawned(mob: Node3D)

@export var mob_scene: PackedScene
@export var base_mob_count: int = 3
@export var mob_count_per_day: int = 2

var _wave_number: int = 0
var _active_mobs: Array[Node3D] = []
var _is_active: bool = false

func _ready() -> void:
	TimeManager.night_started.connect(_on_night_started)
	TimeManager.dawn_started.connect(_on_dawn_started)

func _on_night_started() -> void:
	_wave_number += 1
	_is_active = true
	var count: int = base_mob_count + (GameManager.current_day - 1) * mob_count_per_day
	wave_started.emit(_wave_number, count)
	print("WaveManager: Wave %d — spawning %d mobs (stub — no mob scene set)" % [_wave_number, count])
	# Phase 5: spawn mobs from mob_scene at SpawnPoints

func _on_dawn_started() -> void:
	_is_active = false
	# Phase 5: despawn remaining mobs
	wave_ended.emit(_wave_number)
	print("WaveManager: Wave %d ended at dawn" % _wave_number)

func register_mob(mob: Node3D) -> void:
	_active_mobs.append(mob)
	mob_spawned.emit(mob)

func on_mob_died(mob: Node3D) -> void:
	_active_mobs.erase(mob)
	if _active_mobs.is_empty() and _is_active:
		print("WaveManager: All mobs defeated!")
