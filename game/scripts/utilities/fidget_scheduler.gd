class_name FidgetScheduler
extends RefCounted

## FidgetScheduler
##
## The "now and then" of a hero's idle fidgets (CharacterVisual): once
## the hero stands idle, a fidget comes after a random wait of
## GAP_MIN..GAP_MAX seconds, never the same one twice in a row. Not
## idle (moving, in an action, down) it never fires, and the wait starts
## over once the hero is idle again (so after each fidget too).
##
##   var fidgets := FidgetScheduler.new([&"fidget_look", &"fidget_scratch"])
##   var fidget: StringName = fidgets.tick(delta, idle)   # &"" or one to play

## The wait before a fidget, seconds of standing idle.
const GAP_MIN: float = 6.0
const GAP_MAX: float = 12.0

var _fidgets: Array[StringName] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _until_next: float = 0.0
var _last: int = -1
var _restart: bool = false


## `fidgets` are the states to pick from; `seed` fixes the picks (tests),
## -1 picks a random one.
func _init(fidgets: Array[StringName], seed: int = -1) -> void:
	_fidgets = fidgets.duplicate()
	if seed < 0:
		_rng.randomize()
	else:
		_rng.seed = seed
	_until_next = _next_gap()


## Advances the wait by `delta` seconds; returns the fidget to play now,
## or &"".
func tick(delta: float, idle: bool) -> StringName:
	if _fidgets.is_empty():
		return &""
	if not idle:
		# Moving, in an action (a fidget too) or down: the wait starts
		# again once the hero stands idle.
		_restart = true
		return &""
	if _restart:
		_restart = false
		_until_next = _next_gap()
	_until_next -= delta
	if _until_next > 0.0:
		return &""
	_until_next = _next_gap()
	# Any but the last one played (unless it is the only one).
	var pick: int = _rng.randi_range(0, _fidgets.size() - 1)
	if pick == _last and _fidgets.size() > 1:
		pick = (pick + 1 + _rng.randi_range(0, _fidgets.size() - 2)) % _fidgets.size()
	_last = pick
	return _fidgets[pick]


func _next_gap() -> float:
	return _rng.randf_range(GAP_MIN, GAP_MAX)
