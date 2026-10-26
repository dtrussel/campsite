class_name CharacterLook
extends RefCounted

## CharacterLook
##
## A character visual's head look-at (CharacterVisual composes one when
## `head_look` is on). The head and chest turn toward a focus that
## gameplay sets (Hero picks it with HeadLook's target order), eased and
## capped at MAX_DEGREES, and back to ahead during full-body actions.
## The turn itself is a HeadLookModifier on the skeleton.

## The most the head and chest turn together, degrees.
const MAX_DEGREES: float = 60.0
## How quickly the turn eases toward its goal (per second).
const EASE: float = 6.0
## Actions the look gives way to; &"cheer" only on the whole body.
const OFF_ACTIONS: Array[StringName] = [&"hit", &"death", &"getup"]

var _modifier: HeadLookModifier = null
var _focus: Node3D = null
var _yaw: float = 0.0


## A look on `skeleton`, or null when it has no chest and head to turn.
static func attach(skeleton: Skeleton3D) -> CharacterLook:
	if not HeadLookModifier.fits(skeleton):
		return null
	var look: CharacterLook = CharacterLook.new()
	look._modifier = HeadLookModifier.new()
	look._modifier.name = &"HeadLook"
	skeleton.add_child(look._modifier)
	return look


## True when an action `state` playing on `layer` ("full" or "upper")
## turns the look back to ahead.
static func blocked_by(state: StringName, layer: String) -> bool:
	return OFF_ACTIONS.has(state) or (state == &"cheer" and layer == "full")


func set_focus(node: Node3D) -> void:
	_focus = node


## What the head is set to look at, or null.
func focus() -> Node3D:
	return _focus if is_instance_valid(_focus) else null


## The head's turn from the body last frame, degrees; positive turns
## from +Z toward +X, as rotation.y does.
func turned_degrees() -> float:
	return _modifier.turned_degrees


## Eases the turn toward the focus as seen from `body`, capped; toward
## ahead with no focus or while `blocked`.
func tick(delta: float, body: Node3D, blocked: bool) -> void:
	var goal: float = 0.0
	var target: Node3D = focus()
	if target != null and not blocked:
		var to: Vector3 = target.global_position - body.global_position
		if Vector2(to.x, to.z).length_squared() > 0.01:
			var cap: float = deg_to_rad(MAX_DEGREES)
			goal = clampf(angle_difference(body.global_rotation.y, atan2(to.x, to.z)), -cap, cap)
	_yaw = lerpf(_yaw, goal, clampf(delta * EASE, 0.0, 1.0))
	_modifier.yaw = _yaw
