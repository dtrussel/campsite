extends Node3D

## CameraFollow
##
## LoL-style camera rig: a fixed, north-up, steep angle that smoothly
## follows the boy. The mouse wheel zooms between `min_zoom` and
## `max_zoom`; Fx.shake() adds decaying trauma for hit feedback.

@export var target_path: NodePath
@export var smoothing: float = 6.0
@export var offset: Vector3 = Vector3.ZERO
@export var pitch_degrees: float = 56.0
@export var distance: float = 15.0
@export var min_zoom: float = 0.65
@export var max_zoom: float = 1.3
@export var zoom_step: float = 0.1
@export var max_shake_offset: float = 0.35

var _target: Node3D = null
var _camera: Camera3D = null
var _zoom: float = 1.0
var _zoom_target: float = 1.0
var _trauma: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	add_to_group("camera_rig")
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node3D
	for child in get_children():
		if child is Camera3D:
			_camera = child
			break
	if _target != null:
		global_position = _target.global_position + offset
	_apply_camera()


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_target = clampf(_zoom_target - zoom_step, min_zoom, max_zoom)
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_target = clampf(_zoom_target + zoom_step, min_zoom, max_zoom)


func _process(delta: float) -> void:
	_time += delta
	if _target != null and is_instance_valid(_target):
		var desired: Vector3 = _target.global_position + offset
		global_position = global_position.lerp(desired, clampf(smoothing * delta, 0.0, 1.0))
	_zoom = lerpf(_zoom, _zoom_target, clampf(10.0 * delta, 0.0, 1.0))
	_trauma = maxf(0.0, _trauma - delta * 1.8)
	_apply_camera()


func _apply_camera() -> void:
	if _camera == null:
		return
	var pitch: float = deg_to_rad(pitch_degrees)
	var d: float = distance * _zoom
	var shake: Vector3 = Vector3.ZERO
	if _trauma > 0.0:
		var power: float = _trauma * _trauma * max_shake_offset
		shake = Vector3(sin(_time * 53.0), sin(_time * 47.0 + 1.3), 0.0) * power
	_camera.position = Vector3(0.0, sin(pitch) * d, cos(pitch) * d) + shake
	_camera.rotation = Vector3(-pitch, 0.0, 0.0)
