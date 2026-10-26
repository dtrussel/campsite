class_name BlinkScheduler
extends RefCounted

## BlinkScheduler
##
## When a face blinks (CharacterVisual's face atlas): a blink shuts the
## eyes for BLINK_SECONDS after a random wait of GAP_MIN..GAP_MAX
## seconds, and now and then (DOUBLE_CHANCE) a second blink follows
## right after the first, DOUBLE_GAP seconds later.
##
##   var blinks := BlinkScheduler.new()
##   var shut: bool = blinks.tick(delta)   # true while the eyes are closed

## The wait between blinks, seconds.
const GAP_MIN: float = 2.0
const GAP_MAX: float = 6.0
## How long the eyes stay shut.
const BLINK_SECONDS: float = 0.12
## The chance a blink is a double blink, and the open beat between its two.
const DOUBLE_CHANCE: float = 0.2
const DOUBLE_GAP: float = 0.1

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Seconds until the eyes next shut, then how long they stay shut.
var _until_shut: float = 0.0
var _shut_left: float = 0.0
## A second blink to come after this one.
var _double_pending: bool = false
## The blink coming is the second of a double.
var _second: bool = false


## `seed` fixes the waits (tests); -1 picks a random one.
func _init(seed: int = -1) -> void:
	if seed < 0:
		_rng.randomize()
	else:
		_rng.seed = seed
	_until_shut = _rng.randf_range(GAP_MIN, GAP_MAX)


## Advances by `delta` seconds; true while the eyes are shut.
func tick(delta: float) -> bool:
	if _shut_left > 0.0:
		_shut_left -= delta
		if _shut_left > 0.0:
			return true
		# Open again: straight into the second of a double blink, or wait.
		if _double_pending:
			_double_pending = false
			_second = true
			_until_shut = DOUBLE_GAP
		else:
			_until_shut = _rng.randf_range(GAP_MIN, GAP_MAX)
		return false
	_until_shut -= delta
	if _until_shut > 0.0:
		return false
	_shut_left = BLINK_SECONDS
	# The first blink of a pair may be a double; the second never is.
	_double_pending = not _second and _rng.randf() < DOUBLE_CHANCE
	_second = false
	return true
