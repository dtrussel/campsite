class_name BuildBeat
extends RefCounted

## BuildBeat
##
## The hammering rhythm builders share (feature 045): the hero on a BUILD
## command and the companion on its Repair task. With the hammer out it
## loops two overhead blows, then fetches the next plank (or fiddles a
## peg in), and calls Building.on_build_hit() on each blow's impact
## frame. Progress itself still comes per frame from the caller
## (Building.add_build_progress), so build times do not depend on clips.

const HAMMER_SPEED: float = 1.8
const FETCH_SPEED: float = 1.6
## Share of the hammer clip at which the mallet lands.
const IMPACT_AT: float = 0.52
## Fallback beat length when a clip is missing.
const FALLBACK_SECONDS: float = 0.6

var hits: int = 0
var _beat: int = 0
var _beat_left: float = 0.0
var _impact_in: float = -1.0
var _site: Building = null


## Advances the rhythm; true when a new beat starts (face the site then).
func tick(delta: float, visual: CharacterVisual, site: Building) -> bool:
	if visual == null or site == null:
		return false
	if site != _site:
		_site = site
		_beat = 0
		_beat_left = 0.0
		_impact_in = -1.0
	visual.show_tool(&"hammer")
	if _impact_in >= 0.0:
		_impact_in -= delta
		if _impact_in < 0.0:
			hits += 1
			site.on_build_hit()
	_beat_left -= delta
	if _beat_left > 0.0:
		return false
	var step: int = _beat % 3
	_beat += 1
	if step < 2:
		_beat_left = visual.play_action(&"hammer", HAMMER_SPEED)
		_impact_in = _beat_left * IMPACT_AT
	else:
		var fetch: StringName = &"pick" if (_beat / 3) % 2 == 1 else &"tinker"
		_beat_left = visual.play_action(fetch, FETCH_SPEED)
		_impact_in = -1.0
	if _beat_left <= 0.0:
		_beat_left = FALLBACK_SECONDS
	return true


## A single blow for a repair tap (no fetch beats).
func swing(visual: CharacterVisual) -> void:
	if visual == null:
		return
	visual.show_tool(&"hammer")
	visual.play_action(&"hammer", HAMMER_SPEED)


## Puts the hammer away.
func stop(visual: CharacterVisual) -> void:
	_site = null
	_beat = 0
	_beat_left = 0.0
	_impact_in = -1.0
	if visual != null:
		visual.hide_tool()
