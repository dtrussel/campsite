class_name MumArrival
extends Node3D

## MumArrival
##
## The true ending in the camp (docs/design/story.md):
## after the last night of Chapter 2, Mum walks out of the woods to the
## kids, waves, and they cheer. Then the ending storybook opens. It
## runs while the world is paused behind the end screen, and a click,
## Space or Enter skips it.
##
##   var arrival: MumArrival = MumArrival.play(scene_root, player.global_position)
##   await arrival.finished

signal finished

const MODEL_PATH: String = "res://assets/custom/mum.glb"
## A grown-up next to the kids (Leo 0.7, Nela 0.65 on the same rig).
const MODEL_SCALE: float = 0.72
const CLIPS: Dictionary = {
	&"idle": "Idle", &"walk": "Walking_A", &"move": "Walking_A", &"wave": "Wave", &"cheer": "Cheer",
	&"sit": "Sit_Floor_Idle",
}
const WALK_SPEED: float = 1.7
## Where she comes from and stops, relative to the played hero: out of
## the trees at the top of the screen, to just in front of the kids.
const START_OFFSET: Vector3 = Vector3(-2.5, 0, -9.0)
const STOP_OFFSET: Vector3 = Vector3(-1.1, 0, -1.5)
const WAVE_SECONDS: float = 2.6

var visual: CharacterVisual = null
var target: Vector3 = Vector3.ZERO
var _done: bool = false
var _waving: bool = false
var _kids: Array[CharacterVisual] = []


## Mum's model as a CharacterVisual (also seated on the title screen).
static func make_visual(idle_clip: String = "Idle") -> CharacterVisual:
	var mum: CharacterVisual = CharacterVisual.new()
	mum.name = "Mum"
	mum.model_scene = load(MODEL_PATH)
	mum.model_scale = MODEL_SCALE
	mum.style = "hero"
	var clips: Dictionary = CLIPS.duplicate()
	clips[&"idle"] = idle_clip
	mum.clips = clips
	return mum


static func play(parent: Node, near: Vector3) -> MumArrival:
	var arrival: MumArrival = MumArrival.new()
	arrival.target = Vector3(near.x, 0.0, near.z) + STOP_OFFSET
	parent.add_child(arrival)
	arrival.global_position = Vector3(near.x, 0.0, near.z) + START_OFFSET
	return arrival


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("mum")
	visual = make_visual()
	add_child(visual)
	visual.face_instantly(target - global_position)
	PlaytestLog.write("mum_arrives")


func _process(delta: float) -> void:
	if _done or _waving:
		return
	var to_target: Vector3 = target - global_position
	to_target.y = 0.0
	if to_target.length() <= 0.1:
		_wave()
		return
	var step: Vector3 = to_target.normalized() * minf(WALK_SPEED * delta, to_target.length())
	global_position += step
	visual.set_locomotion(WALK_SPEED)
	visual.face(to_target, delta)


func _wave() -> void:
	_waving = true
	visual.set_locomotion(0.0)
	visual.play_action(&"wave")
	# The kids turn to her and cheer; their visuals run while the world
	# is paused, just for this.
	for group in ["player", "companions"]:
		for node in get_tree().get_nodes_in_group(group):
			var kid: CharacterVisual = node.get_node_or_null("Visual") as CharacterVisual
			if kid == null:
				continue
			kid.process_mode = Node.PROCESS_MODE_ALWAYS
			kid.face_instantly(global_position - (node as Node3D).global_position)
			kid.play_action(&"cheer")
			_kids.append(kid)
	AudioManager.play_sfx(&"win")
	await get_tree().create_timer(WAVE_SECONDS, true, false, true).timeout
	finish()


func _input(event: InputEvent) -> void:
	if _done:
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if event.is_action_pressed("ui_accept") or (click != null and click.pressed):
		get_viewport().set_input_as_handled()
		finish()


## Ends the moment (also the skip). Mum stays by the kids.
func finish() -> void:
	if _done:
		return
	_done = true
	if not _waving:
		global_position = target
		visual.set_locomotion(0.0)
	for kid in _kids:
		if is_instance_valid(kid):
			kid.process_mode = Node.PROCESS_MODE_INHERIT
	finished.emit()
