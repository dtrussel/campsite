class_name BarkSet
extends Resource

## BarkSet
##
## The siblings' barks (feature 037, docs/design/story.md): short lines
## over a hero's head when something happens in a run. Each line is a
## dictionary like a StoryBeat line:
##   {"id": "bark.thief.leo.1", "trigger": "thief", "speaker": "leo", "text": "..."}
## - `speaker`: a hero id; the director picks a line for whoever speaks.
## - `when` (optional): only when that hero is played.
## - The voice recording is found by the line id (StoryLibrary.voice);
##   until there is one, the speaker's chirp plays.
## `triggers` tunes each trigger:
##   {"role": "subject", "cooldown": 20.0, "urgent": false, "once": "night"}
## - `role`: who speaks. `hero` (the played hero), `companion`,
##   `subject` (the hero it happened to) or `call_response` (the played
##   hero, then the companion replies).
## - `cooldown`: seconds before this trigger barks again.
## - `urgent`: skips the shared cooldown and an open story card.
## - `once`: "night" barks once per night (day number), "run" once per
##   run, "" any time.

const ROLES: Array[String] = ["hero", "companion", "subject", "call_response"]

@export var triggers: Dictionary = {}
@export var lines: Array = []
