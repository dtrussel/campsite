extends Node3D

## CameraFollow
##
## Smoothly follows a target node's position with a fixed offset.
## Phase 0 uses this to keep the isometric camera centered on the
## boy. Rotation of the camera is left to the camera node itself.

@export var target_path: NodePath
@export var smoothing: float = 6.0
@export var offset: Vector3 = Vector3.ZERO

var _target: Node3D = null


func _ready() -> void:
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node3D


func _process(delta: float) -> void:
	if _target == null:
		return
	var desired: Vector3 = _target.global_position + offset
	var t: float = clamp(smoothing * delta, 0.0, 1.0)
	global_position = global_position.lerp(desired, t)
