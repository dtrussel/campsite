class_name SpringChainModifier
extends SkeletonModifier3D

## SpringChainModifier
##
## Swings short bone chains (hair locks, a backpack, hanging gear) on
## top of whatever the animation posed, so they lag, swing and settle
## when the character turns, stops or is hit. Each chain (SpringChain)
## is simulated in world space: every bone's far end is a point that a
## spring pulls toward where the animation puts it, damped, with an
## optional pull downward, kept at the bone's length and within the
## chain's reach limit of the animated direction. CharacterVisual owns
## one on a hero's skeleton. Godot 4.3 has no spring bone modifier; the
## built-in one can replace this after an engine upgrade.

## The simulation's fixed step (seconds), and the most game time one
## frame may simulate (a long frame loses the rest, never explodes).
const STEP_SECONDS: float = 1.0 / 120.0
const MAX_FRAME_SECONDS: float = 0.25
## A tip further than this (m) from its target has been teleported
## (the character placed somewhere new): it starts again at rest.
const TELEPORT_DISTANCE: float = 2.0

var chains: Array[SpringChain] = []
## While true the chains hold where they are (the visual's hit-stop):
## they pose as last simulated and do not move on.
var paused: bool = false
## The largest distance (m) between a chain's tip and where the
## animation puts it, last frame (tests, through CharacterVisual).
var swing: float = 0.0
## The largest such distance at any simulation step since
## `clear_peak()`: a long frame can swing a chain out and back before
## the frame ends, which `swing` alone would miss (tests).
var peak_swing: float = 0.0

## Per chain: bone indices (the last one the tip), and per swinging
## bone its simulated far end (world) and that point's velocity.
var _indices: Array[PackedInt32Array] = []
var _points: Array[PackedVector3Array] = []
var _velocities: Array[PackedVector3Array] = []
var _started: bool = false


## True when all of `chain`'s bones are in `skeleton`.
static func fits(skeleton: Skeleton3D, chain: SpringChain) -> bool:
	return skeleton != null and chain != null and _bone_indices(skeleton, chain).size() >= 2


static func _bone_indices(skeleton: Skeleton3D, chain: SpringChain) -> PackedInt32Array:
	var found: PackedInt32Array = PackedInt32Array()
	for bone in chain.bones:
		var index: int = skeleton.find_bone(bone)
		if index == -1:
			return PackedInt32Array()
		found.append(index)
	return found


func _process_modification() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null or chains.is_empty():
		return
	if not _started:
		_start(skeleton)
	var frame: float = 0.0 if paused else minf(get_process_delta_time(), MAX_FRAME_SECONDS)
	var steps: int = ceili(frame / STEP_SECONDS - 0.001) if frame > 0.0 else 0
	var step: float = frame / steps if steps > 0 else 0.0
	var to_world: Transform3D = skeleton.global_transform
	var widest: float = 0.0
	for c in chains.size():
		var bones: PackedInt32Array = _indices[c]
		if bones.size() < 2:
			continue
		var chain: SpringChain = chains[c]
		var animated_tip: Vector3 = to_world * skeleton.get_bone_global_pose(bones[-1]).origin
		for i in bones.size() - 1:
			_swing_bone(skeleton, to_world, chain, c, i, steps, step, animated_tip if i == bones.size() - 2 else null)
		widest = maxf(widest, _points[c][bones.size() - 2].distance_to(animated_tip))
	swing = widest
	peak_swing = maxf(peak_swing, widest)


## Starts the peak swing again from nothing.
func clear_peak() -> void:
	peak_swing = 0.0


## Simulates bone `i` of chain `c` for `steps` of `step` seconds toward
## its animated direction, then turns the bone to point at the result.
## For the chain's last swinging bone, `animated_tip` is where the
## animation puts the tip, and every step's distance from it counts
## toward `peak_swing`.
func _swing_bone(skeleton: Skeleton3D, to_world: Transform3D, chain: SpringChain, c: int, i: int, steps: int,
		step: float, animated_tip: Variant) -> void:
	var bone: int = _indices[c][i]
	var pose: Transform3D = skeleton.get_bone_global_pose(bone)
	var child_origin: Vector3 = skeleton.get_bone_global_pose(_indices[c][i + 1]).origin
	var head: Vector3 = to_world * pose.origin
	var target: Vector3 = to_world * child_origin
	var length: float = head.distance_to(target)
	if length < 0.0001:
		return
	var point: Vector3 = _points[c][i]
	var velocity: Vector3 = _velocities[c][i]
	if point.distance_to(target) > TELEPORT_DISTANCE:
		point = target
		velocity = Vector3.ZERO
	var reach: float = deg_to_rad(chain.max_degrees)
	for s in steps:
		var before: Vector3 = point
		velocity += ((target - point) * chain.stiffness + Vector3.DOWN * chain.gravity) * step
		velocity *= maxf(0.0, 1.0 - chain.damping * step)
		point = _constrain(head, target, point + velocity * step, length, reach)
		velocity = (point - before) / step
		if animated_tip != null:
			peak_swing = maxf(peak_swing, point.distance_to(animated_tip))
	point = _constrain(head, target, point, length, reach)
	_points[c][i] = point
	_velocities[c][i] = velocity
	# Turn the bone from its animated direction to the simulated one.
	var from_local: Vector3 = child_origin - pose.origin
	var to_local: Vector3 = to_world.affine_inverse() * point - pose.origin
	if from_local.length_squared() < 1e-10 or to_local.length_squared() < 1e-10:
		return
	var turn: Quaternion = Quaternion(from_local.normalized(), to_local.normalized())
	var parent: int = skeleton.get_bone_parent(bone)
	var parent_rot: Quaternion = Quaternion.IDENTITY
	if parent != -1:
		parent_rot = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var local: Quaternion = skeleton.get_bone_pose_rotation(bone)
	skeleton.set_bone_pose_rotation(bone, (parent_rot.inverse() * turn * parent_rot * local).normalized())


## `point` kept at `length` from `head`, within `reach` radians of the
## animated direction (head to target).
static func _constrain(head: Vector3, target: Vector3, point: Vector3, length: float, reach: float) -> Vector3:
	var rest: Vector3 = (target - head).normalized()
	var dir: Vector3 = point - head
	if dir.length_squared() < 1e-10:
		return target
	dir = dir.normalized()
	var angle: float = rest.angle_to(dir)
	if angle > reach:
		var axis: Vector3 = rest.cross(dir)
		if axis.length_squared() < 1e-10:
			axis = rest.cross(Vector3.UP if absf(rest.y) < 0.9 else Vector3.RIGHT)
		dir = rest.rotated(axis.normalized(), reach)
	return head + dir * length


## Every chain starts at rest where the animation first puts it.
func _start(skeleton: Skeleton3D) -> void:
	_started = true
	_indices.clear()
	_points.clear()
	_velocities.clear()
	var to_world: Transform3D = skeleton.global_transform
	for chain in chains:
		var bones: PackedInt32Array = _bone_indices(skeleton, chain) if chain != null else PackedInt32Array()
		var points: PackedVector3Array = PackedVector3Array()
		var velocities: PackedVector3Array = PackedVector3Array()
		for i in range(1, bones.size()):
			points.append(to_world * skeleton.get_bone_global_pose(bones[i]).origin)
			velocities.append(Vector3.ZERO)
		_indices.append(bones)
		_points.append(points)
		_velocities.append(velocities)
