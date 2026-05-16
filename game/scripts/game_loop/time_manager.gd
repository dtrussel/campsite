extends Node

## Controls the day/night cycle timer. Emits phase transition signals.
## normalized_time: 0.0 = start of day, 1.0 = end of night (full cycle)

signal day_started
signal sunset_warning(seconds_remaining: float)
signal night_started
signal dawn_started
signal time_updated(normalized_time: float)

@export var day_duration_seconds: float = 180.0   # seconds of day phase
@export var sunset_duration_seconds: float = 20.0  # warning window
@export var night_duration_seconds: float = 60.0   # night phase length
@export var dawn_duration_seconds: float = 10.0    # brief dawn transition

var _elapsed: float = 0.0
var _phase_elapsed: float = 0.0
var _current_phase: String = "day"
var _sunset_warned: bool = false

func _ready() -> void:
	_start_day()

func _process(delta: float) -> void:
	_elapsed += delta
	_phase_elapsed += delta

	match _current_phase:
		"day":
			var remaining: float = day_duration_seconds - _phase_elapsed
			if not _sunset_warned and remaining <= sunset_duration_seconds:
				_sunset_warned = true
				sunset_warning.emit(remaining)
			if _phase_elapsed >= day_duration_seconds:
				_start_night()

		"night":
			if _phase_elapsed >= night_duration_seconds:
				_start_dawn()

		"dawn":
			if _phase_elapsed >= dawn_duration_seconds:
				_start_day()

	var total_cycle: float = day_duration_seconds + night_duration_seconds + dawn_duration_seconds
	time_updated.emit(fmod(_elapsed, total_cycle) / total_cycle)

func _start_day() -> void:
	_current_phase = "day"
	_phase_elapsed = 0.0
	_sunset_warned = false
	day_started.emit()

func _start_night() -> void:
	_current_phase = "night"
	_phase_elapsed = 0.0
	night_started.emit()

func _start_dawn() -> void:
	_current_phase = "dawn"
	_phase_elapsed = 0.0
	dawn_started.emit()

func get_phase() -> String:
	return _current_phase

func get_day_progress() -> float:
	if _current_phase == "day":
		return _phase_elapsed / day_duration_seconds
	return 1.0
