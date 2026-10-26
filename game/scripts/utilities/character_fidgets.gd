class_name CharacterFidgets
extends RefCounted

## CharacterFidgets
##
## A character visual's idle fidgets (CharacterVisual composes one when
## it has `fidgets`): it times the wait (FidgetScheduler) while the visual
## stands idle and keeps the tallies tests read. The visual plays the
## fidget on its whole body, cuts it short when moving and forgets it
## when any other action replaces it. The wait pauses through a hit-stop
## (the visual does not tick it then), like the rest of the pose.

## The fidget playing (cleared by any other action).
var playing: StringName = &""
## Fidgets played so far, the last one and how long the visual stood
## idle before it (tests).
var played: int = 0
var last: StringName = &""
var last_wait: float = 0.0

var _scheduler: FidgetScheduler = null
var _idle_seconds: float = 0.0


func _init(fidgets: Array[StringName]) -> void:
	_scheduler = FidgetScheduler.new(fidgets)


## Advances the wait (`idle`: the visual stands idle, out of any action);
## the fidget due now, or &"".
func tick(delta: float, idle: bool) -> StringName:
	_idle_seconds = _idle_seconds + delta if idle else 0.0
	return _scheduler.tick(delta, idle)


## The visual started `fidget`.
func started(fidget: StringName) -> void:
	last_wait = _idle_seconds
	playing = fidget
	last = fidget
	played += 1
