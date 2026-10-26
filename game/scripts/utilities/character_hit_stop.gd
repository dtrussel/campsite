class_name CharacterHitStop
extends RefCounted

## CharacterHitStop
##
## A character visual's hit-stop (CharacterVisual composes one). As a
## hero's hit lands (Hero.on_attack_hit), the attacker's and the target's
## visuals hold their pose for a blink, and the target squashes and
## springs back. Only the visual stops: its animation mixers go to manual
## processing, its spring chains pause, and the visual skips its turn,
## lean, look, face and fidgets while `tick` says it is held. The body,
## its damage and knockback, and every other character keep going.

## How long a hit-stop holds, game seconds.
const SECONDS: float = 0.05
## It also holds for at least this many frames, so a slow frame still
## shows it.
const MIN_FRAMES: int = 2
## The target's squash: this much wider and shorter, held through the
## stop, then back over SQUASH_RECOVER_SECONDS.
const SQUASH: float = 0.12
const SQUASH_RECOVER_SECONDS: float = 0.14

var _model: Node3D = null
var _model_scale: float = 1.0
var _mixers: Array[AnimationMixer] = []
var _springs: SpringChainModifier = null
var _stopped: bool = false
var _left: float = 0.0
var _frames: int = 0
## Each frozen mixer's own process mode, to restore.
var _modes: Dictionary = {}  # AnimationMixer -> callback mode
var _squash_left: float = 0.0


## The stop for `model` (drawn at `model_scale`), freezing `mixers` and
## pausing `springs` (null: none).
func _init(model: Node3D, model_scale: float, mixers: Array[AnimationMixer], springs: SpringChainModifier) -> void:
	_model = model
	_model_scale = model_scale
	_mixers = mixers
	_springs = springs


## Freezes the visual for a blink (SECONDS); with `squash`, it squashes
## too and recovers after. A new stop during one extends it.
func stop(squash: bool) -> void:
	_left = maxf(_left, SECONDS) if _stopped else SECONDS
	_frames = 0
	_stopped = true
	if _springs != null:
		_springs.paused = true
	for mixer in _mixers:
		if not _modes.has(mixer):
			_modes[mixer] = mixer.callback_mode_process
			mixer.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if squash:
		_squash_left = SQUASH_RECOVER_SECONDS
		_apply_squash(1.0)


func is_stopped() -> bool:
	return _stopped


## Runs the stop and the squash's recovery; true while the visual is held.
func tick(delta: float) -> bool:
	if _stopped:
		_left -= delta
		_frames += 1
		if _left > 0.0 or _frames < MIN_FRAMES:
			return true
		_stopped = false
		if _springs != null:
			_springs.paused = false
		for mixer in _modes:
			if is_instance_valid(mixer):
				(mixer as AnimationMixer).callback_mode_process = _modes[mixer]
		_modes.clear()
		return false
	if _squash_left > 0.0:
		_squash_left = maxf(_squash_left - delta, 0.0)
		_apply_squash(ease(_squash_left / SQUASH_RECOVER_SECONDS, 2.0))
	return false


## The squash at `amount` (1: full, 0: none) on the model.
func _apply_squash(amount: float) -> void:
	var squash: float = SQUASH * amount
	_model.scale = Vector3(1.0 + squash, 1.0 - squash, 1.0 + squash) * _model_scale
