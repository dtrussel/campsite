class_name HeadLookModifier
extends SkeletonModifier3D

## HeadLookModifier
##
## Turns the chest and head about the up axis by `yaw` radians on top of
## whatever the animation posed, the chest taking CHEST_SHARE of it and
## the head the rest. CharacterVisual owns one on a hero's skeleton and
## sets `yaw` each frame (eased and capped); this node only applies it.
## Godot 4.3 has no built-in look-at modifier; one can replace this
## after an engine upgrade.

const CHEST_BONE: String = "chest"
const HEAD_BONE: String = "head"
## The chest's share of the turn; the head takes the rest.
const CHEST_SHARE: float = 0.4

## The combined turn to apply, radians about the up axis (positive turns
## the face from +Z toward +X, as a body's rotation.y does).
var yaw: float = 0.0
## The head's actual turn last applied, degrees (tests read it through
## CharacterVisual.look_turn_degrees).
var turned_degrees: float = 0.0


## True when `skeleton` has the bones this modifier turns.
static func fits(skeleton: Skeleton3D) -> bool:
	return skeleton != null and skeleton.find_bone(CHEST_BONE) != -1 and skeleton.find_bone(HEAD_BONE) != -1


func _process_modification() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return
	var head: int = skeleton.find_bone(HEAD_BONE)
	var chest: int = skeleton.find_bone(CHEST_BONE)
	if head == -1 or chest == -1:
		return
	if absf(yaw) < 0.0001:
		turned_degrees = 0.0
		return
	var up: Vector3 = (skeleton.global_basis.inverse() * Vector3.UP).normalized()
	var before: Vector3 = skeleton.get_bone_global_pose(head).basis.z
	_turn(skeleton, chest, up, yaw * CHEST_SHARE)
	_turn(skeleton, head, up, yaw * (1.0 - CHEST_SHARE))
	var after: Vector3 = skeleton.get_bone_global_pose(head).basis.z
	turned_degrees = rad_to_deg(_planar(before, up).signed_angle_to(_planar(after, up), up))


## Rotates `bone` by `angle` about `up` (skeleton space), around its own
## origin, keeping its children attached.
func _turn(skeleton: Skeleton3D, bone: int, up: Vector3, angle: float) -> void:
	var parent: int = skeleton.get_bone_parent(bone)
	var parent_rot: Quaternion = Quaternion.IDENTITY
	if parent != -1:
		parent_rot = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var turn: Quaternion = Quaternion(up, angle)
	var local: Quaternion = skeleton.get_bone_pose_rotation(bone)
	skeleton.set_bone_pose_rotation(bone, (parent_rot.inverse() * turn * parent_rot * local).normalized())


static func _planar(v: Vector3, up: Vector3) -> Vector3:
	return v - up * v.dot(up)
