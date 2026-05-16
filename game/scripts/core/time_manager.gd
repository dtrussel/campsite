extends Node

## TimeManager
##
## Drives the day/night cycle. Phase 0 stub: holds a time-of-day
## value in [0, 1) and emits structural signals so other systems
## can subscribe today. The actual day/night transitions are
## fleshed out in Phase 5.

signal day_started(day_number: int)
signal sunset_warning(seconds_until_night: float)
signal night_started(day_number: int)
signal dawn_started(day_number: int)

enum Phase { DAY, SUNSET, NIGHT, DAWN }

@export var seconds_per_full_day: float = 240.0

var time_of_day: float = 0.25  # 0.0 = midnight, 0.25 = morning
var current_phase: int = Phase.DAY
var day_number: int = 1


func _ready() -> void:
	# Announce day 1 starting so listeners can initialize.
	day_started.emit(day_number)


func _process(delta: float) -> void:
	# Phase 0 only advances the clock value; no transitions yet.
	if seconds_per_full_day <= 0.0:
		return
	time_of_day = fposmod(time_of_day + delta / seconds_per_full_day, 1.0)


func get_phase_label() -> String:
	# Naive label until Phase 5 introduces real phase transitions.
	if time_of_day < 0.25:
		return "Night"
	elif time_of_day < 0.5:
		return "Morning"
	elif time_of_day < 0.75:
		return "Afternoon"
	else:
		return "Evening"
