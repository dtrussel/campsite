extends Node

## GameManager
##
## Top-level coordinator. Owns high-level run state and forwards
## requests between subsystems. Phase 0 keeps this thin: it just
## holds the current day number and listens to TimeManager.

signal day_number_changed(new_day: int)

var current_day: int = 1


func _ready() -> void:
	# Connect to TimeManager once the autoload tree is up.
	if TimeManager and not TimeManager.day_started.is_connected(_on_day_started):
		TimeManager.day_started.connect(_on_day_started)


func _on_day_started(day_number: int) -> void:
	current_day = day_number
	day_number_changed.emit(current_day)
