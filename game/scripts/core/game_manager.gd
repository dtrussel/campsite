extends Node

## Owns top-level game state. Coordinates phase transitions between day/night.

enum GamePhase { DAY, SUNSET, NIGHT, DAWN }

signal game_phase_changed(new_phase: GamePhase)
signal game_over
signal new_day_started(day_number: int)

var current_day: int = 1
var game_phase: GamePhase = GamePhase.DAY

func _ready() -> void:
	TimeManager.day_started.connect(_on_day_started)
	TimeManager.sunset_warning.connect(_on_sunset_warning)
	TimeManager.night_started.connect(_on_night_started)
	TimeManager.dawn_started.connect(_on_dawn_started)

func _on_day_started() -> void:
	game_phase = GamePhase.DAY
	game_phase_changed.emit(game_phase)
	new_day_started.emit(current_day)

func _on_sunset_warning(seconds_remaining: float) -> void:
	game_phase = GamePhase.SUNSET
	game_phase_changed.emit(game_phase)

func _on_night_started() -> void:
	game_phase = GamePhase.NIGHT
	game_phase_changed.emit(game_phase)

func _on_dawn_started() -> void:
	game_phase = GamePhase.DAWN
	current_day += 1
	game_phase_changed.emit(game_phase)

func trigger_game_over() -> void:
	game_over.emit()

func get_phase_name() -> String:
	match game_phase:
		GamePhase.DAY:    return "Day"
		GamePhase.SUNSET: return "Sunset"
		GamePhase.NIGHT:  return "Night"
		GamePhase.DAWN:   return "Dawn"
	return "Unknown"
