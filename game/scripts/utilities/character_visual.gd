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
##   visual.action_contact_in()       # seconds to the action's contact frame
##   visual.set_look_focus(node)      # head and chest turn toward it (null: ahead)
##   visual.hit_stop(squash)          # freeze for a blink as a hit lands
##
## With `spring_chains` (a hero's hair, pack, hanging gear), a
## SpringChainModifier swings those bones on top of the clips.
##
## With a `face_atlas`, the face blinks now and then (BlinkScheduler) and
## shows an expression through a hit, a cheer and being down.
##
## Standing idle, it plays one of its `fidgets` now and then
## (FidgetScheduler); moving, any action or going down cuts it short.
##
## Animation is layered with an AnimationTree built in code:
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
## The run blends in from walk_speed up to this many times it.
const RUN_START_FACTOR: float = 2.2
## The walk's play speed range when it is scaled by the real speed.
const WALK_PLAY_MIN: float = 0.5
const WALK_PLAY_MAX: float = 2.0

## Hand tools: key -> model, held on TOOL_BONE.
const TOOLS: Dictionary = {&"hammer": preload("res://assets/custom/hammer.glb")}
const TOOL_BONE: String = "handslot.r"
## Tool models have the grip at the origin, the handle up +Y and the
## head along X: in the hand bone's frame that points the handle forward
## out of the fist (X runs along the forearm). Drawn a bit large so it
## reads from the game camera.
const TOOL_SCALE: float = 1.9

@export var model_scene: PackedScene
@export var model_scale: float = 1.0
## Accessory nodes (BoneAttachment3D or MeshInstance3D names) to hide.
@export var hidden_parts: PackedStringArray = PackedStringArray()
## Optional prop placed on a named bone attachment (e.g. an axe).
@export var prop_scene: PackedScene
@export var prop_attachment: String = ""
@export var prop_transform: Transform3D = Transform3D.IDENTITY
@export_enum("hero", "shadow") var style: String = "hero"
## The model's outfit mesh (the body and clothes, "Leo") and the badge
## cosmetic tint it wears (Cosmetics; white is the painted look).
@export var outfit_mesh: String = ""
@export var outfit_tint: Color = Color.WHITE
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
## The ground speed (m/s) the walk clip is authored for: its stride over
## its length. The walk plays faster or slower with the real speed so its
## feet stay planted; 0 plays it at its natural rate (a stock walk).
@export var walk_reference_speed: float = 0.0
## Lean into turns.
@export var lean: bool = true
## Fx.burst kind puffed at the feet every `step_distance` metres while
## running; empty = none.
@export var footstep_dust: StringName = &""
@export var step_distance: float = 1.1
## Model parts put away while a hand tool is out (Leo's stick, Nela's
## lantern); set by HeroBody.
@export var tool_hidden_parts: PackedStringArray = PackedStringArray()
## Logical state -> seconds into its clip (at speed 1) of the contact
## frame, where a blow connects (a hero's `attack`); set by HeroBody.
@export var contact_times: Dictionary = {}
## Turn the head and chest toward a look focus (`set_look_focus`); set by
## HeroBody. Needs a skeleton with "chest" and "head" bones.
@export var head_look: bool = false
## Idle fidgets: states in `clips` played now and then while standing
## idle (a hero's, from HeroDefinition.fidgets). Empty: none.
@export var fidgets: Array[StringName] = []
## Spring chains the model's bones swing on (a hero's, from
## HeroDefinition.spring_chains). Empty: none.
@export var spring_chains: Array[SpringChain] = []
## The head's face atlas (a hero's, from HeroDefinition.face_atlas; Mum's
## from MumArrival): blinks and expressions. Null: a still face.
@export var face_atlas: FaceAtlas = null

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
var _tool_slot: BoneAttachment3D = null
var _tools: Dictionary = {}  # key -> Node3D
var _tool_key: StringName = &""
## Game seconds until the playing action's contact frame (< 0: none).
var _contact_remaining: float = -1.0
## Footstep puffs made so far (tests).
var steps_puffed: int = 0
## The action last played (its state and layer), for the look's blend-out.
var _action_state: StringName = &""
var _action_layer: String = ""
var _look: HeadLookModifier = null
var _look_focus: Node3D = null
var _look_yaw: float = 0.0


## Dresses the outfit mesh in `color` now (hero select's preview).
func set_outfit_tint(color: Color) -> void:
	outfit_tint = color
	var mesh: MeshInstance3D = _tag_outfit()
	if mesh != null:
		Stylize.apply_mesh(mesh, style)


func _tag_outfit() -> MeshInstance3D:
	if model == null or outfit_mesh == "":
		return null
	var mesh: MeshInstance3D = model.find_child(outfit_mesh, true, false) as MeshInstance3D
	if mesh != null:
		mesh.set_meta(Stylize.TINT_META, outfit_tint)
	return mesh


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
	_tag_outfit()
	Stylize.apply(model, style)
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player != null:
		for state in [&"idle", &"walk", &"move", &"flee"]:
			var anim: Animation = _get_clip(state)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
		_build_tree()
	_last_yaw = rotation.y
	if head_look:
		_add_head_look()
	if not spring_chains.is_empty():
		_add_springs()
	if face_atlas != null:
		_add_face()


## Called every physics frame with the character's planar speed.
func set_locomotion(speed: float) -> void:
	_speed = speed
	if _locked or _tree == null:
		return
	if is_moving() and fidget_playing() != &"":
		_cancel_fidget()
	var delta: float = get_physics_process_delta_time()
	_blend_position = lerpf(_blend_position, speed, clampf(delta * 14.0, 0.0, 1.0))
	if speed < move_threshold and _blend_position < move_threshold:
		_blend_position = 0.0
	_tree.set("parameters/loco/blend_position", _blend_position)
	# Stride matching: the walk and the run speed up and slow down with
	# the character, so their feet keep pace with the ground.
	_tree.set("parameters/loco_speed/scale", locomotion_play_speed(speed, _blend_position))
	var run_weight: float = _run_weight(_blend_position) if clips.has(&"walk") \
		else (1.0 if speed > move_threshold else 0.0)
	_tick_footsteps(run_weight)


## How fast the move clip plays at `speed` m/s for a character whose
## move clip fits `reference_speed` (the validator's clip checks too).
static func run_play_speed(speed: float, reference_speed: float) -> float:
	return clampf(speed / reference_speed, 0.6, 1.4)


## How fast the walk clip plays at `speed` m/s for a walk authored for
## `walk_reference_speed` (its stride over its length); 0 = 1x.
static func walk_play_speed(speed: float, walk_reference_speed: float) -> float:
	if walk_reference_speed <= 0.0:
		return 1.0
	return clampf(speed / walk_reference_speed, WALK_PLAY_MIN, WALK_PLAY_MAX)


## How fast the locomotion blend plays at `speed` m/s with the blend at
## `blend_position`: the idle at 1x, the walk and the run at their
## stride-matched speeds, mixed by their weights in the blend.
func locomotion_play_speed(speed: float, blend_position: float) -> float:
	var run_scale: float = run_play_speed(speed, reference_speed)
	if not clips.has(&"walk"):
		return run_scale if speed > move_threshold else 1.0
	var run_weight: float = _run_weight(blend_position)
	var walk_weight: float = clampf(blend_position / maxf(walk_speed, 0.01), 0.0, 1.0) * (1.0 - run_weight)
	return (1.0 - walk_weight - run_weight) + walk_weight * walk_play_speed(speed, walk_reference_speed) \
		+ run_weight * run_scale


## The run's share of the walk-to-run blend at `blend_position`.
func _run_weight(blend_position: float) -> float:
	var run_start: float = walk_speed * RUN_START_FACTOR
	return clampf((blend_position - walk_speed) / maxf(run_start - walk_speed, 0.01), 0.0, 1.0)


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
	_contact_remaining = -1.0
	_fidget = &""
	if _locked or _player == null:
		return 0.0
	var anim: Animation = _get_clip(state)
	if anim == null:
		return 0.0
	var length: float = anim.length / maxf(speed, 0.01)
	_action_until_msec = Time.get_ticks_msec() + int(length * 1000.0)
	var contact: float = float(contact_times.get(state, 0.0))
	_contact_remaining = contact / maxf(speed, 0.01) if contact > 0.0 and contact < anim.length else -1.0
	_action_state = state
	_action_layer = "full" if _tree == null or not is_moving() else "upper"
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
	_contact_remaining = -1.0
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


## Puts `key`'s tool in the right hand (and the usual hand-held parts
## away). Building and repairing use &"hammer".
func show_tool(key: StringName) -> void:
	if key == _tool_key or model == null or not TOOLS.has(key):
		return
	if _tool_slot == null:
		var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false) as Skeleton3D
		if skeleton == null or skeleton.find_bone(TOOL_BONE) == -1:
			return
		_tool_slot = BoneAttachment3D.new()
		_tool_slot.name = &"ToolSlot"
		_tool_slot.bone_name = TOOL_BONE
		skeleton.add_child(_tool_slot)
	if _tool_key != &"":
		(_tools[_tool_key] as Node3D).visible = false
	if not _tools.has(key):
		var tool: Node3D = (TOOLS[key] as PackedScene).instantiate() as Node3D
		tool.scale = Vector3.ONE * TOOL_SCALE
		_tool_slot.add_child(tool)
		Stylize.apply(tool, style)
		_tools[key] = tool
	(_tools[key] as Node3D).visible = true
	_tool_key = key
	_set_tool_parts_visible(false)


func hide_tool() -> void:
	if _tool_key == &"":
		return
	(_tools[_tool_key] as Node3D).visible = false
	_tool_key = &""
	_set_tool_parts_visible(true)


## The tool in hand, or &"" (tests).
func tool_shown() -> StringName:
	return _tool_key


func _set_tool_parts_visible(shown: bool) -> void:
	for part in tool_hidden_parts:
		var node: Node3D = model.find_child(part, true, false) as Node3D
		if node != null and not hidden_parts.has(part):
			node.visible = shown


## True while an action plays (a fidget does not count: anything may
## cut it short).
func is_in_action() -> bool:
	return _action_playing() and _fidget == &""


func _action_playing() -> bool:
	return Time.get_ticks_msec() < _action_until_msec


## Game seconds from now until the contact frame of the action playing
## (play_action), at its play speed; -1 when it has none (no contact
## time for its state) or it has passed.
func action_contact_in() -> float:
	return _contact_remaining if _contact_remaining > 0.0 else -1.0


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


## The state of the action playing now (play_action), or &""; tests.
func playing_action() -> StringName:
	return _action_state if _action_playing() and not _locked else &""


## The clip a play_final holds on its last frame once it has played
## through, or "" (still falling, or nothing held); tests.
func held_clip() -> String:
	if not _locked or _player == null or _player.is_playing() or _player.assigned_animation == &"":
		return ""
	var anim: Animation = _player.get_animation(_player.assigned_animation)
	if anim == null or absf(_player.current_animation_position - anim.length) > 0.001:
		return ""
	return String(_player.assigned_animation)


func get_animation_tree() -> AnimationTree:
	return _tree


## Smoothly turns the model toward a planar direction, leaning into
## the turn a little.
func face(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001 or model == null or is_hit_stopped():
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
	if _contact_remaining > 0.0:
		_contact_remaining -= delta
	if _tick_hit_stop(delta):
		return
	_tick_fidgets(delta)
	_tick_face(delta)
	if _look != null:
		_tick_look(delta)
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
		_run_start = walk_speed * RUN_START_FACTOR
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
## Mushroom Gremlin's &"flee" scurry); &"move" restores it.
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


# --- Head look-at ------------------------------------------------------------
# The head and chest turn toward a focus that gameplay sets (Hero picks
# it with HeadLook's target order), eased and capped at LOOK_MAX_DEGREES,
# and back to ahead during full-body actions.

## The most the head and chest turn together, degrees.
const LOOK_MAX_DEGREES: float = 60.0
## How quickly the turn eases toward its goal (per second).
const LOOK_EASE: float = 6.0
## Actions the look gives way to; &"cheer" only on the whole body.
const LOOK_OFF_ACTIONS: Array[StringName] = [&"hit", &"death", &"getup"]


## Looks at `node` from now on (null: straight ahead again).
func set_look_focus(node: Node3D) -> void:
	_look_focus = node


## What the head is set to look at, or null (tests).
func look_focus() -> Node3D:
	return _look_focus if is_instance_valid(_look_focus) else null


## The head's turn from the body last frame, degrees; positive turns
## from +Z toward +X, as rotation.y does (tests).
func look_turn_degrees() -> float:
	return _look.turned_degrees if _look != null else 0.0


func _add_head_look() -> void:
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if not HeadLookModifier.fits(skeleton):
		return
	_look = HeadLookModifier.new()
	_look.name = &"HeadLook"
	skeleton.add_child(_look)


## Eases the turn toward the focus, capped; toward ahead with no focus
## or during a full-body action.
func _tick_look(delta: float) -> void:
	var goal: float = 0.0
	var focus: Node3D = look_focus()
	if focus != null and not _look_blocked():
		var to: Vector3 = focus.global_position - global_position
		if Vector2(to.x, to.z).length_squared() > 0.01:
			var cap: float = deg_to_rad(LOOK_MAX_DEGREES)
			goal = clampf(angle_difference(global_rotation.y, atan2(to.x, to.z)), -cap, cap)
	_look_yaw = lerpf(_look_yaw, goal, clampf(delta * LOOK_EASE, 0.0, 1.0))
	_look.yaw = _look_yaw


func _look_blocked() -> bool:
	if _locked:
		return true
	if not is_in_action():
		return false
	return LOOK_OFF_ACTIONS.has(_action_state) or (_action_state == &"cheer" and _action_layer == "full")


# --- Hit-stop ----------------------------------------------------------------
# As a hero's hit lands (Hero.on_attack_hit), the attacker's and the
# target's visuals hold their pose for a blink, and the target squashes
# and springs back. Only the visual stops: its animation mixers go to
# manual processing, and the turn, lean and look wait. The body, its
# damage and knockback, and every other character keep going.

## How long a hit-stop holds, game seconds.
const HIT_STOP_SECONDS: float = 0.05
## It also holds for at least this many frames, so a slow frame still
## shows it.
const HIT_STOP_MIN_FRAMES: int = 2
## The target's squash: this much wider and shorter, held through the
## stop, then back over SQUASH_RECOVER_SECONDS.
const SQUASH: float = 0.12
const SQUASH_RECOVER_SECONDS: float = 0.14

var _stopped: bool = false
var _stop_left: float = 0.0
var _stop_frames: int = 0
## Each frozen mixer's own process mode, to restore.
var _stopped_mixers: Dictionary = {}  # AnimationMixer -> callback mode
var _squash_left: float = 0.0


## Freezes this visual for a blink (HIT_STOP_SECONDS); with `squash`, it
## squashes too and recovers after. A new stop during one extends it.
func hit_stop(squash: bool = false) -> void:
	if model == null:
		return
	_stop_left = maxf(_stop_left, HIT_STOP_SECONDS) if _stopped else HIT_STOP_SECONDS
	_stop_frames = 0
	_stopped = true
	if _springs != null:
		_springs.paused = true
	for mixer in [_tree, _player]:
		if mixer != null and not _stopped_mixers.has(mixer):
			_stopped_mixers[mixer] = (mixer as AnimationMixer).callback_mode_process
			(mixer as AnimationMixer).callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if squash:
		_squash_left = SQUASH_RECOVER_SECONDS
		_apply_squash(1.0)


## True while a hit-stop holds this visual.
func is_hit_stopped() -> bool:
	return _stopped


## Runs the stop and the squash's recovery; true while the visual is held.
func _tick_hit_stop(delta: float) -> bool:
	if _stopped:
		_stop_left -= delta
		_stop_frames += 1
		if _stop_left > 0.0 or _stop_frames < HIT_STOP_MIN_FRAMES:
			return true
		_stopped = false
		if _springs != null:
			_springs.paused = false
		for mixer in _stopped_mixers:
			if is_instance_valid(mixer):
				(mixer as AnimationMixer).callback_mode_process = _stopped_mixers[mixer]
		_stopped_mixers.clear()
		return false
	if _squash_left > 0.0:
		_squash_left = maxf(_squash_left - delta, 0.0)
		_apply_squash(ease(_squash_left / SQUASH_RECOVER_SECONDS, 2.0))
	return false


## The squash at `amount` (1: full, 0: none) on the model.
func _apply_squash(amount: float) -> void:
	var squash: float = SQUASH * amount
	model.scale = Vector3(1.0 + squash, 1.0 - squash, 1.0 + squash) * model_scale


# --- Idle fidgets ------------------------------------------------------------
# Standing idle, the visual plays one of its `fidgets` on the whole body
# now and then (FidgetScheduler's wait). Moving cuts it short back to
# locomotion, and any other action replaces it. The wait pauses through
# a hit-stop (_process returns before it), like the rest of the pose.

var _fidget_scheduler: FidgetScheduler = null
## The fidget playing (cleared by any other action).
var _fidget: StringName = &""
var _idle_seconds: float = 0.0
## Fidgets played so far, the last one and how long the visual stood
## idle before it (tests).
var fidgets_played: int = 0
var last_fidget: StringName = &""
var last_fidget_wait: float = 0.0


## The fidget playing now, or &"".
func fidget_playing() -> StringName:
	return _fidget if _action_playing() else &""


func _tick_fidgets(delta: float) -> void:
	if fidgets.is_empty() or _tree == null:
		return
	if _fidget_scheduler == null:
		_fidget_scheduler = FidgetScheduler.new(fidgets)
	var idle: bool = not _locked and not is_moving() and not _action_playing()
	_idle_seconds = _idle_seconds + delta if idle else 0.0
	var fidget: StringName = _fidget_scheduler.tick(delta, idle)
	if fidget == &"" or _get_clip(fidget) == null:
		return
	last_fidget_wait = _idle_seconds
	play_action(fidget)
	_fidget = fidget
	last_fidget = fidget
	fidgets_played += 1


## Fades the fidget out, back to locomotion.
func _cancel_fidget() -> void:
	_tree.set("parameters/full/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	_tree.set("parameters/upper/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	_action_until_msec = 0
	_fidget = &""


# --- Spring chains -----------------------------------------------------------
# Hair, packs and hanging gear swing on short bone chains that no clip
# keys (SpringChainModifier), after the look-at has turned the head. They
# hold still through a hit-stop, as the rest of the pose does, and swing
# on from there.

var _springs: SpringChainModifier = null


## How many spring chains swing on this visual's model (tests).
func spring_chain_count() -> int:
	return _springs.chains.size() if _springs != null else 0


## The largest distance (m) between a chain's tip and where the clip puts
## it, last frame: 0 at rest, more while swinging (tests).
func spring_swing() -> float:
	return _springs.swing if _springs != null else 0.0


func _add_springs() -> void:
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var fitting: Array[SpringChain] = []
	for chain in spring_chains:
		if SpringChainModifier.fits(skeleton, chain):
			fitting.append(chain)
	if fitting.is_empty():
		return
	_springs = SpringChainModifier.new()
	_springs.name = &"SpringChains"
	_springs.chains = fitting
	skeleton.add_child(_springs)


# --- Face --------------------------------------------------------------------
# The head's face surface shows one cell of its FaceAtlas
# (painted_face.gdshader): the neutral face, blinking now and then
# (BlinkScheduler), or an expression for as long as a hit or a cheer
# plays, and dazed while down (play_final). Like the rest of the pose it
# holds through a hit-stop (_process returns before _tick_face).

const FACE_SHADER: Shader = preload("res://shaders/painted_face.gdshader")
## Action state -> the expression it shows while it plays.
const FACE_EXPRESSIONS: Dictionary = {&"hit": &"hurt", &"cheer": &"happy"}
## The expression while down.
const FACE_DOWN: StringName = &"dazed"

var _face_material: ShaderMaterial = null
var _blinks: BlinkScheduler = null
var _face_shown: StringName = &""
## Blinks shown so far (tests).
var blinks_shown: int = 0


## The face state the head shows now (&"open", &"closed", &"hurt", ...),
## read back from its material; &"" without a face atlas (tests).
func face_shown() -> StringName:
	if _face_material == null:
		return &""
	var origin: Vector2 = _face_material.get_shader_parameter("cell_origin")
	for i in face_atlas.states.size():
		if face_atlas.cell_origins[i].is_equal_approx(origin):
			return StringName(face_atlas.states[i])
	return &""


func _add_face() -> void:
	var head: MeshInstance3D = model.find_child(face_atlas.mesh, true, false) as MeshInstance3D
	if head == null or head.mesh == null:
		return
	for surface in head.mesh.get_surface_count():
		var source: Material = head.mesh.surface_get_material(surface)
		if source == null or source.resource_name != face_atlas.material:
			continue
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = FACE_SHADER
		var styled: ShaderMaterial = head.get_surface_override_material(surface) as ShaderMaterial
		if styled != null:
			# The head's own painted look (Stylize) and its ink line.
			for uniform in styled.shader.get_shader_uniform_list():
				var key: StringName = StringName(uniform["name"])
				material.set_shader_parameter(key, styled.get_shader_parameter(key))
			material.next_pass = styled.next_pass
		elif source is BaseMaterial3D:
			material.set_shader_parameter("albedo_texture", (source as BaseMaterial3D).albedo_texture)
		material.set_shader_parameter("face_atlas", face_atlas.texture)
		var window: Rect2 = face_atlas.window
		material.set_shader_parameter("face_window", Vector4(window.position.x, window.position.y,
			window.size.x, window.size.y))
		material.set_shader_parameter("cell_size", face_atlas.cell_size)
		head.set_surface_override_material(surface, material)
		_face_material = material
		_blinks = BlinkScheduler.new()
		_show_face(FaceAtlas.NEUTRAL)
		return


## Picks this frame's face: the expression of the action playing or of
## being down, else neutral with its blinks.
func _tick_face(delta: float) -> void:
	if _face_material == null:
		return
	var state: StringName = FACE_DOWN if _locked else FACE_EXPRESSIONS.get(playing_action(), FaceAtlas.NEUTRAL)
	if not face_atlas.has_state(state):
		state = FaceAtlas.NEUTRAL
	var shut: bool = _blinks.tick(delta)
	if state == FaceAtlas.NEUTRAL and shut:
		state = FaceAtlas.BLINK
		if _face_shown != FaceAtlas.BLINK:
			blinks_shown += 1
	_show_face(state)


func _show_face(state: StringName) -> void:
	if state == _face_shown:
		return
	_face_shown = state
	_face_material.set_shader_parameter("cell_origin", face_atlas.cell_origin(state))
