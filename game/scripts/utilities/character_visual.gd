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
##   visual.set_locomotion(speed)     # idle <-> move by speed
##   visual.play_action(&"attack")    # one-shot, returns length
##   visual.face(direction, delta)    # smooth turn toward a direction

const BLEND_SECONDS: float = 0.15
const TURN_SPEED: float = 12.0

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

var model: Node3D = null
var _player: AnimationPlayer = null
var _loop_state: StringName = &"idle"
var _action_until_msec: int = 0
var _locked: bool = false  # death: stay on the last pose


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
		for state in [&"idle", &"move"]:
			var anim: Animation = _get_clip(state)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
		_play_clip(&"idle", 0.0)


## Called every physics frame with the character's planar speed.
func set_locomotion(speed: float) -> void:
	if _locked or _player == null:
		return
	var state: StringName = &"move" if speed > move_threshold else &"idle"
	if state == &"move":
		_player.speed_scale = clampf(speed / reference_speed, 0.6, 1.4)
	else:
		_player.speed_scale = 1.0
	if Time.get_ticks_msec() < _action_until_msec:
		_loop_state = state
		return
	if state != _loop_state or not _player.is_playing():
		_loop_state = state
		_play_clip(state, BLEND_SECONDS)


## Plays a one-shot clip; locomotion resumes when it ends. Returns the
## clip length in seconds (0 if the state has no clip).
func play_action(state: StringName, speed: float = 1.0) -> float:
	if _locked or _player == null:
		return 0.0
	var anim: Animation = _get_clip(state)
	if anim == null:
		return 0.0
	_player.speed_scale = speed
	_play_clip(state, 0.08)
	var length: float = anim.length / maxf(speed, 0.01)
	_action_until_msec = Time.get_ticks_msec() + int(length * 1000.0)
	return length


## Plays a clip and freezes on its last frame (death / knock-out).
func play_final(state: StringName) -> float:
	var length: float = play_action(state)
	_locked = true
	return length


## Leaves a play_final pose (e.g. a companion getting back up).
func unlock(state: StringName = &"idle") -> void:
	_locked = false
	_action_until_msec = 0
	var length: float = play_action(state)
	if length <= 0.0:
		_play_clip(&"idle", BLEND_SECONDS)


func is_in_action() -> bool:
	return Time.get_ticks_msec() < _action_until_msec


## Smoothly turns the model toward a planar direction.
func face(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001 or model == null:
		return
	var target_yaw: float = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))


func face_instantly(direction: Vector3) -> void:
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		rotation.y = atan2(direction.x, direction.z)


func _get_clip(state: StringName) -> Animation:
	if _player == null:
		return null
	var clip: String = String(clips.get(state, ""))
	if clip == "" or not _player.has_animation(clip):
		return null
	return _player.get_animation(clip)


func _play_clip(state: StringName, blend: float) -> void:
	var clip: String = String(clips.get(state, ""))
	if clip == "" or not _player.has_animation(clip):
		clip = String(clips.get(&"idle", "Idle"))
		if not _player.has_animation(clip):
			return
	_player.play(clip, blend)
