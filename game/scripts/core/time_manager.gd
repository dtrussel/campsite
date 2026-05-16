extends Node

## TimeManager
##
## Drives the day/night cycle. Owns the current phase, a per-phase
## countdown, and the transition signals. Other systems subscribe
## rather than poll.

signal day_started(day_number: int)
signal sunset_warning(seconds_until_night: float)
signal night_started(day_number: int)
signal dawn_started(day_number: int)
signal phase_changed(new_phase: int)

enum Phase { DAY, SUNSET, NIGHT, DAWN }

@export var day_seconds: float = 90.0
@export var sunset_seconds: float = 8.0
@export var night_seconds: float = 60.0
@export var dawn_seconds: float = 5.0

var current_phase: int = Phase.DAY
var remaining_seconds: float = 0.0
var day_number: int = 1


func _ready() -> void:
	current_phase = Phase.DAY
	remaining_seconds = day_seconds
	phase_changed.emit(current_phase)
	day_started.emit(day_number)


func _process(delta: float) -> void:
	remaining_seconds -= delta
	if remaining_seconds <= 0.0:
		_advance_phase()


func get_phase_name() -> String:
	match current_phase:
		Phase.DAY: return "Day"
		Phase.SUNSET: return "Sunset"
		Phase.NIGHT: return "Night"
		Phase.DAWN: return "Dawn"
	return "?"


func get_phase_label() -> String:
	return get_phase_name()


func is_night() -> bool:
	return current_phase == Phase.NIGHT


func _advance_phase() -> void:
	match current_phase:
		Phase.DAY:
			current_phase = Phase.SUNSET
			remaining_seconds = sunset_seconds
			sunset_warning.emit(sunset_seconds)
		Phase.SUNSET:
			current_phase = Phase.NIGHT
			remaining_seconds = night_seconds
			night_started.emit(day_number)
		Phase.NIGHT:
			current_phase = Phase.DAWN
			remaining_seconds = dawn_seconds
			dawn_started.emit(day_number)
		Phase.DAWN:
			day_number += 1
			current_phase = Phase.DAY
			remaining_seconds = day_seconds
			day_started.emit(day_number)
	phase_changed.emit(current_phase)
