class_name RunOutcome
extends RefCounted

## RunOutcome
##
## How a run ended, as the profile hears it (see GLOSSARY.md, "Run
## outcome"): the run config, whether it was won, the night it ended on
## and a copy of the run's stats. GameManager builds one when a run is
## won or lost and hands it to Profile.record_run_end, which answers
## with a Result.

var config: RunConfig
var won: bool
## The night the run ended on (GameManager.current_day).
var night: int
## The run's stats (stat -> count), copied so later runs leave it be.
var stats: Dictionary


func _init(run: RunConfig, run_won: bool, ended_night: int, run_stats: Dictionary) -> void:
	config = run
	won = run_won
	night = ended_night
	stats = run_stats.duplicate()


## What a run's end opened, as Profile.record_run_end returns it. The
## badges it earned are not here: the profile announces those with
## badge_earned.
class Result:
	extends RefCounted

	## The run beat the endless record (the end screen says "New
	## record!").
	var record_beaten: bool = false
	## The unlocks it opened for good: &"chapter_2", &"endless".
	var unlocked: Array[StringName] = []
