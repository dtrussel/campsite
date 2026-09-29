class_name CharacterVisual
extends Node3D

## CharacterVisual
##
## The visible, animated body of a character. Instances a rigged
## KayKit model, hides the accessories we do not want, attaches an
## optional hand prop, applies the house style, and maps logical
## states (idle, move, attack, ...) to the model's animation clips.
##
## Gameplay scripts only talk to this node:
##   visual.set_locomotion(speed)     # idle / walk / run blend by speed
##   visual.play_action(&"attack")    # one-shot, returns length
##   visual.face(direction, delta)    # smooth turn toward a direction
##
## Feature 023: animation is layered with an AnimationTree built in code:
##
##   BlendSpace1D "loco" (idle . walk . run by speed) -> TimeScale
##     -> OneShot "upper" (spine, chest, head and arms only)
##     -> OneShot "full"  (whole body)
##
## An action played while moving goes to the upper body, so the legs
## keep running (Leo swings while he runs); standing still it plays on
## the whole body. play_final (death, knock-out) bypasses the tree and
## holds the last frame. Characters lean a little into their turns.

const BLEND_SECONDS: float = 0.15
const TURN_SPEED: float = 12.0
## Bones an upper-body action drives; the hips and legs keep the gait.
const UPPER_BONES: Array[String] = ["spine", "chest", "head", "upperarm.l", "lowerarm.l", "wrist.l", "hand.l",
	"handslot.l", "upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "handslot.r"]
const MAX_LEAN: float = 0.17  # radians (~10 degrees) into a turn
const LEAN_PER_TURN_RATE: float = 0.045

@export var model_scene: PackedScene
@export var model_scale: float = 1.0
## Accessory nodes (BoneAttachment3D or MeshInstance3D names) to hide.
@export var hidden_parts: PackedStringArray = PackedStringArray()
## Optional prop placed on a named bone attachment (e.g. an axe).
@export var prop_scene: PackedScene
@export var prop_attachment: String = ""
@export var prop_transform: Transform3D = Transform3D.IDENTITY
@export_enum("hero", "shadow") var style: String = "hero"
## Logical state -> clip name. Missing states fall back to "idle".
## An optional &"walk" clip is blended between idle and move by speed.
@export var clips: Dictionary = {
	&"idle": "Idle",
	&"move": "Running_A",
	&"attack": "1H_Melee_Attack_Chop",
	&"gather": "Interact",
	&"hit": "Hit_A",
	&"death": "Death_A",
	&"cheer": "Cheer",
}
## Speeds above this play the move clip.
@export var move_threshold: float = 0.3
## Playback speed of the move clip at `reference_speed` m/s.
@export var reference_speed: float = 5.0
## Speed (m/s) at which the walk clip plays fully; running takes over
## above about twice this. Only used when there is a &"walk" clip.
@export var walk_speed: float = 1.6
## Lean into turns (feature 023).
@export var lean: bool = true
## Fx.burst kind puffed at the feet every `step_distance` metres while
## running (feature 024); empty = none.
@export var footstep_dust: StringName = &""
@export var step_distance: float = 1.1

var model: Node3D = null
var _player: AnimationPlayer = null
var _tree: AnimationTree = null
var _upper_anim: AnimationNodeAnimation = null
var _full_anim: AnimationNodeAnimation = null
var _move_anim: AnimationNodeAnimation = null  # the loco "move" point (swappable)
var _run_start: float = 1.0
var _blend_position: float = 0.0
var _speed: float = 0.0
var _action_until_msec: int = 0
var _locked: bool = false  # death: stay on the last pose
var _lean_target: float = 0.0
var _lean: float = 0.0
var _last_yaw: float = 0.0
var _last_step_pos: Vector3 = Vector3.INF
var _step_travel: float = 0.0
## Footstep puffs made so far (tests).
var steps_puffed: int = 0


func _ready() -> void:
	if model_scene == null:
		return
	model = model_scene.instantiate() as Node3D
	model.scale = Vector3.ONE * model_scale
	add_child(model)
	for part in hidden_parts:
		var node: Node = model.find_child(part, true, false)
		if node is Node3D:
			(node as Node3D).visible = false
	if prop_scene != null and prop_attachment != "":
		var attachment: Node = model.find_child(prop_attachment, true, false)
		if attachment != null:
			# The prop replaces whatever the model already holds there.
			for child in attachment.get_children():
				if child is Node3D:
					(child as Node3D).visible = false
			var prop: Node3D = prop_scene.instantiate() as Node3D
			prop.transform = prop_transform
			attachment.add_child(prop)
	Stylize.apply(model, style)
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player != null:
		for state in [&"idle", &"walk", &"move", &"flee"]:
			var anim: Animation = _get_clip(state)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
		_build_tree()
	_last_yaw = rotation.y


## Called every physics frame with the character's planar speed.
func set_locomotion(speed: float) -> void:
	_speed = speed
	if _locked or _tree == null:
		return
	var delta: float = get_physics_process_delta_time()
	_blend_position = lerpf(_blend_position, speed, clampf(delta * 14.0, 0.0, 1.0))
	if speed < move_threshold and _blend_position < move_threshold:
		_blend_position = 0.0
	_tree.set("parameters/loco/blend_position", _blend_position)
	# The run clip speeds up and slows down with the character, as before;
	# idle and walk play at their natural rate.
	var run_weight: float = clampf((_blend_position - walk_speed) / maxf(_run_start - walk_speed, 0.01), 0.0, 1.0) \
		if clips.has(&"walk") else (1.0 if speed > move_threshold else 0.0)
	var run_scale: float = clampf(speed / reference_speed, 0.6, 1.4)
	_tree.set("parameters/loco_speed/scale", lerpf(1.0, run_scale, run_weight))
	_tick_footsteps(run_weight)


func _tick_footsteps(run_weight: float) -> void:
	if footstep_dust == &"" or not is_inside_tree():
		return
	var here: Vector3 = global_position
	if _last_step_pos != Vector3.INF and run_weight > 0.5:
		_step_travel += Vector2(here.x - _last_step_pos.x, here.z - _last_step_pos.z).length()
		if _step_travel >= step_distance:
			_step_travel = 0.0
			steps_puffed += 1
			Fx.burst(footstep_dust, here + Vector3(0, 0.05, 0))
	_last_step_pos = here


## Plays a one-shot clip; locomotion resumes when it ends. Returns the
## clip length in seconds (0 if the state has no clip). While moving it
## plays on the upper body only.
func play_action(state: StringName, speed: float = 1.0) -> float:
	if _locked or _player == null:
		return 0.0
	var anim: Animation = _get_clip(state)
	if anim == null:
		return 0.0
	var length: float = anim.length / maxf(speed, 0.01)
	_action_until_msec = Time.get_ticks_msec() + int(length * 1000.0)
	if _tree == null:
		_player.speed_scale = speed
		_player.play(String(clips[state]), 0.08)
		return length
	var layer: String = "upper" if is_moving() else "full"
	var node: AnimationNodeAnimation = _upper_anim if layer == "upper" else _full_anim
	node.animation = StringName(clips[state])
	_tree.set("parameters/%s_speed/scale" % layer, speed)
	# Only one action at a time: a new one replaces the other layer's.
	var other: String = "full" if layer == "upper" else "upper"
	_tree.set("parameters/%s/request" % other, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	_tree.set("parameters/%s/request" % layer, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	return length


## Plays a clip and freezes on its last frame (death / knock-out).
func play_final(state: StringName) -> float:
	if _player == null:
		return 0.0
	var anim: Animation = _get_clip(state)
	if anim == null:
		_locked = true
		return 0.0
	if _tree != null:
		_tree.active = false
	_player.speed_scale = 1.0
	_player.play(String(clips[state]), 0.1)
	_action_until_msec = Time.get_ticks_msec() + int(anim.length * 1000.0)
	_locked = true
	return anim.length


## Leaves a play_final pose (e.g. a companion getting back up).
func unlock(state: StringName = &"idle") -> void:
	_locked = false
	_action_until_msec = 0
	if _tree != null:
		_player.stop()
		_tree.active = true
	play_action(state)


func is_in_action() -> bool:
	return Time.get_ticks_msec() < _action_until_msec


func is_moving() -> bool:
	return _speed > move_threshold


## Which layer an action last fired on ("upper", "full" or ""); tests.
func active_action_layer() -> String:
	if _tree == null:
		return ""
	if bool(_tree.get("parameters/upper/active")):
		return "upper"
	if bool(_tree.get("parameters/full/active")):
		return "full"
	return ""


func get_animation_tree() -> AnimationTree:
	return _tree


## Smoothly turns the model toward a planar direction, leaning into
## the turn a little.
func face(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001 or model == null:
		return
	var target_yaw: float = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))
	if lean and delta > 0.0 and is_moving():
		var turn_rate: float = angle_difference(_last_yaw, rotation.y) / delta
		_lean_target = clampf(-turn_rate * LEAN_PER_TURN_RATE, -MAX_LEAN, MAX_LEAN)
	_last_yaw = rotation.y


func face_instantly(direction: Vector3) -> void:
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		rotation.y = atan2(direction.x, direction.z)
		_last_yaw = rotation.y


func _process(delta: float) -> void:
	if model == null or not lean:
		return
	# Ease into the lean, and back upright when running straight.
	_lean = lerpf(_lean, _lean_target, clampf(delta * 8.0, 0.0, 1.0))
	_lean_target = lerpf(_lean_target, 0.0, clampf(delta * 6.0, 0.0, 1.0))
	var tilt: float = 0.05 if is_moving() and not _locked else 0.0
	model.rotation.z = _lean
	model.rotation.x = lerpf(model.rotation.x, tilt, clampf(delta * 6.0, 0.0, 1.0))


# --- Animation tree ----------------------------------------------------------

func _build_tree() -> void:
	var idle: String = String(clips.get(&"idle", ""))
	var move: String = String(clips.get(&"move", ""))
	if not _player.has_animation(idle) or not _player.has_animation(move):
		_player.play(idle if _player.has_animation(idle) else move)
		return
	var blend_tree: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	var loco: AnimationNodeBlendSpace1D = AnimationNodeBlendSpace1D.new()
	loco.add_blend_point(_clip_node(idle), 0.0)
	var walk: String = String(clips.get(&"walk", ""))
	if walk != "" and _player.has_animation(walk):
		_run_start = walk_speed * 2.2
		loco.add_blend_point(_clip_node(walk), walk_speed)
		_move_anim = _clip_node(move)
		loco.add_blend_point(_move_anim, _run_start)
		loco.max_space = maxf(reference_speed * 2.0, _run_start + 1.0)
	else:
		_run_start = move_threshold * 2.0
		_move_anim = _clip_node(move)
		loco.add_blend_point(_move_anim, _run_start)
		loco.max_space = maxf(reference_speed * 2.0, 1.0)
	loco.min_space = 0.0
	blend_tree.add_node(&"loco", loco)
	blend_tree.add_node(&"loco_speed", AnimationNodeTimeScale.new())
	blend_tree.connect_node(&"loco_speed", 0, &"loco")

	_upper_anim = _clip_node(idle)
	_full_anim = _clip_node(idle)
	for layer in ["upper", "full"]:
		var shot: AnimationNodeOneShot = AnimationNodeOneShot.new()
		shot.fadein_time = 0.08
		shot.fadeout_time = 0.18
		blend_tree.add_node(StringName(layer), shot)
		blend_tree.add_node(StringName(layer + "_anim"), _upper_anim if layer == "upper" else _full_anim)
		blend_tree.add_node(StringName(layer + "_speed"), AnimationNodeTimeScale.new())
		blend_tree.connect_node(StringName(layer + "_speed"), 0, StringName(layer + "_anim"))
		blend_tree.connect_node(StringName(layer), 1, StringName(layer + "_speed"))
	blend_tree.connect_node(&"upper", 0, &"loco_speed")
	blend_tree.connect_node(&"full", 0, &"upper")
	blend_tree.connect_node(&"output", 0, &"full")
	_filter_upper_body(blend_tree.get_node(&"upper") as AnimationNodeOneShot)

	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	_tree.tree_root = blend_tree
	_player.get_parent().add_child(_tree)
	_tree.root_node = _tree.get_path_to(_player.get_node(_player.root_node))
	_tree.anim_player = _tree.get_path_to(_player)
	_tree.active = true
	for layer in ["loco_speed", "upper_speed", "full_speed"]:
		_tree.set("parameters/%s/scale" % layer, 1.0)


func _filter_upper_body(shot: AnimationNodeOneShot) -> void:
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var root: Node = _player.get_node(_player.root_node)
	var skeleton_path: String = String(root.get_path_to(skeleton))
	shot.filter_enabled = true
	for bone in UPPER_BONES:
		if skeleton.find_bone(bone) != -1:
			shot.set_filter_path(NodePath("%s:%s" % [skeleton_path, bone]), true)


## Swaps the locomotion clip for another role in `clips` (e.g. the
## Mushroom Gremlin's &"flee" scurry, feature 027); &"move" restores it.
## Does nothing if the model has no such clip.
func set_move_clip(state: StringName) -> void:
	if _move_anim == null or _get_clip(state) == null:
		return
	_move_anim.animation = StringName(clips[state])


## The clip the locomotion currently uses for moving.
func current_move_clip() -> StringName:
	return _move_anim.animation if _move_anim != null else &""


func _clip_node(clip: String) -> AnimationNodeAnimation:
	var node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	node.animation = StringName(clip)
	return node


func _get_clip(state: StringName) -> Animation:
	if _player == null:
		return null
	var clip: String = String(clips.get(state, ""))
	if clip == "" or not _player.has_animation(clip):
		return null
	return _player.get_animation(clip)
