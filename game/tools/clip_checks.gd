extends RefCounted

## clip_checks.gd
##
## Measures a hero's animation clips as data, for validate_project.gd:
## no scene plays and no Blender is needed. Poses are rebuilt from a
## clip's bone tracks over the skeleton's rest pose, in the skeleton's
## space, and scaled to metres in the game (the hero's model_scale).
##
##   loop_pop()     how far a looping clip's last pose is from its first
##   foot_slide()   how far a planted foot slides per stride at a speed

## Bones whose names hold these are rig controls, not the body.
const CONTROL_MARKERS: Array[String] = ["IK", "control-"]
## A foot this close to its lowest point (metres in the game) is down.
const CONTACT_BAND: float = 0.02
## Clip samples per second of clip time for the foot measures.
const SAMPLES_PER_SECOND: float = 240.0


## The looping states, measured for a pop at the wrap.
const LOOPS: Array[StringName] = [&"idle", &"walk", &"move"]
## Limits: a loop's wrap may jump a joint this far (m) or turn a bone
## this much (deg); a foot may slide this far (m) a stride; an action
## may run this far (s) from its gameplay length.
const LOOP_METRES: float = 0.01
const LOOP_DEGREES: float = 3.0
const SLIDE_METRES: float = 0.04
const DURATION_SECONDS: float = 0.05
## The speed gameplay plays each action at, as the player's hero (the
## companion attacks at 1.45x and gathers at 1.3x). The gather state is
## the companion's; chop and pick are the player's gathers at a node,
## and pick is also the build beat's plank fetch.
const PLAY_SPEEDS: Dictionary = {
	&"attack": 1.5, &"hit": 1.4, &"death": 1.0, &"getup": 1.0, &"cheer": 1.2,
	&"gather": 1.3, &"chop": 1.5, &"pick": 1.5,
	&"tinker": BuildBeat.FETCH_SPEED, &"hammer": BuildBeat.HAMMER_SPEED,
}
## Each action's gameplay length (s, at its play speed): the stock
## clips' lengths, which new clips keep.
const ACTION_SECONDS: Dictionary = {
	&"leo": {
		&"attack": 0.694, &"hit": 0.476, &"death": 0.792, &"getup": 2.333, &"cheer": 1.389,
		&"gather": 0.994, &"chop": 0.694, &"pick": 0.861, &"tinker": 0.990, &"hammer": 0.903,
	},
	&"nela": {
		&"attack": 0.611, &"hit": 0.476, &"death": 0.792, &"getup": 2.333, &"cheer": 1.389,
		&"gather": 0.994, &"chop": 0.694, &"pick": 0.861, &"tinker": 0.990, &"hammer": 0.903,
	},
}
## The per-clip switch from "report" to "enforce": hero id -> state ->
## the checks ("loop", "slide", "duration") that fail the validator
## when over their limit. Every other check only reports.
const ENFORCED: Dictionary = {}


## Measures every clip `hero` maps. One row per check: {hero, state,
## clip, check ("clip", "loop", "slide" or "duration"), value, limit,
## text, over, enforced}. A mapped state without its clip is always
## enforced. `enforced` and `action_seconds` default to the tables above.
static func check_hero(hero: HeroDefinition, enforced: Dictionary = ENFORCED,
		action_seconds: Dictionary = ACTION_SECONDS) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var model: Node = hero.model_scene.instantiate() if hero.model_scene != null else null
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer \
		if model != null else null
	var skeleton: Skeleton3D = _first_skeleton(model) if model != null else null
	var prefix: String = ""
	if player != null and skeleton != null:
		prefix = String(player.get_node(player.root_node).get_path_to(skeleton))
	var switched: Dictionary = enforced.get(hero.id, {})
	var targets: Dictionary = action_seconds.get(hero.id, {})
	var defaults: CharacterVisual = CharacterVisual.new()
	var walk_speed: float = defaults.walk_speed
	defaults.free()
	var states: Array = hero.clips.keys()
	states.sort()
	for state in states:
		var clip: String = String(hero.clips[state])
		var row: Dictionary = {"hero": hero.id, "state": StringName(state), "clip": clip}
		if player == null or skeleton == null or not player.has_animation(clip):
			rows.append(_row(row, "clip", 0.0, 0.0, "has no clip '%s' in its model" % clip, true, true))
			continue
		var anim: Animation = player.get_animation(clip)
		var checks: Array = switched.get(StringName(state), [])
		if LOOPS.has(StringName(state)):
			var pop: Dictionary = loop_pop(anim, skeleton, prefix, hero.model_scale)
			var over: bool = pop.metres > LOOP_METRES or pop.degrees > LOOP_DEGREES
			rows.append(_row(row, "loop", pop.metres, LOOP_METRES, "wraps with a %.1f cm, %.1f deg pop (limit %.1f cm, %.0f deg)"
				% [pop.metres * 100.0, pop.degrees, LOOP_METRES * 100.0, LOOP_DEGREES], over, checks.has("loop")))
		if state == &"walk" or state == &"move":
			var speed: float = walk_speed if state == &"walk" else hero.move_speed
			var play: float = 1.0 if state == &"walk" else CharacterVisual.run_play_speed(speed, hero.reference_speed)
			var slide: float = foot_slide(anim, skeleton, prefix, hero.model_scale, speed, play)
			rows.append(_row(row, "slide", slide, SLIDE_METRES, "slides %.1f cm a stride at %.1f m/s, played at %.2fx (limit %.1f cm)"
				% [slide * 100.0, speed, play, SLIDE_METRES * 100.0], slide > SLIDE_METRES, checks.has("slide")))
		if PLAY_SPEEDS.has(StringName(state)):
			var seconds: float = anim.length / float(PLAY_SPEEDS[StringName(state)])
			var target: float = float(targets.get(StringName(state), seconds))
			rows.append(_row(row, "duration", seconds, target, "lasts %.3f s at %.2fx (gameplay length %.3f s)"
				% [seconds, PLAY_SPEEDS[StringName(state)], target], absf(seconds - target) > DURATION_SECONDS,
				checks.has("duration")))
	if model != null:
		model.free()
	return rows


## The rows that fail the validator: over their limit and enforced.
static func failures(rows: Array[Dictionary]) -> Array[Dictionary]:
	return rows.filter(func(row: Dictionary) -> bool: return row.over and row.enforced)


## One line for a row: "leo walk (Walking_A) slide: slides ... [report, over]".
static func describe(row: Dictionary) -> String:
	var mode: String = "enforce" if row.enforced else "report"
	return "%s %s (%s) %s: %s [%s%s]" % [row.hero, row.state, row.clip, row.check, row.text, mode,
		", OVER" if row.over else ""]


static func _row(base: Dictionary, kind: String, value: float, limit: float, text: String, over: bool,
		enforced: bool) -> Dictionary:
	var row: Dictionary = base.duplicate()
	row.merge({"check": kind, "value": value, "limit": limit, "text": text, "over": over, "enforced": enforced})
	return row


static func _first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found: Skeleton3D = _first_skeleton(child)
		if found != null:
			return found
	return null


## The skeleton-space pose of every bone at clip time `time`.
static func pose(anim: Animation, skeleton: Skeleton3D, prefix: String, time: float) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		var rest: Transform3D = skeleton.get_bone_rest(bone)
		var path: NodePath = NodePath("%s:%s" % [prefix, skeleton.get_bone_name(bone)])
		var position: Vector3 = rest.origin
		var rotation: Quaternion = rest.basis.get_rotation_quaternion()
		var scale: Vector3 = rest.basis.get_scale()
		var track: int = anim.find_track(path, Animation.TYPE_POSITION_3D)
		if track != -1:
			position = anim.position_track_interpolate(track, time)
		track = anim.find_track(path, Animation.TYPE_ROTATION_3D)
		if track != -1:
			rotation = anim.rotation_track_interpolate(track, time)
		track = anim.find_track(path, Animation.TYPE_SCALE_3D)
		if track != -1:
			scale = anim.scale_track_interpolate(track, time)
		var local: Transform3D = Transform3D(Basis(rotation).scaled(scale), position)
		var parent: int = skeleton.get_bone_parent(bone)
		# Bones come after their parents in a Skeleton3D.
		out.append(out[parent] * local if parent != -1 else local)
	return out


## How far the pose jumps when a looping clip wraps from its end to its
## start: {metres} is the largest joint jump (at `model_scale`) and
## {degrees} the largest bone turn. Rig controls are left out.
static func loop_pop(anim: Animation, skeleton: Skeleton3D, prefix: String, model_scale: float) -> Dictionary:
	if anim.loop_mode != Animation.LOOP_NONE:
		# A looping clip reads its end as its start; compare the keys.
		anim = anim.duplicate() as Animation
		anim.loop_mode = Animation.LOOP_NONE
	var first: Array[Transform3D] = pose(anim, skeleton, prefix, 0.0)
	var last: Array[Transform3D] = pose(anim, skeleton, prefix, anim.length)
	var metres: float = 0.0
	var degrees: float = 0.0
	for bone in first.size():
		if _is_control(skeleton.get_bone_name(bone)):
			continue
		metres = maxf(metres, first[bone].origin.distance_to(last[bone].origin) * model_scale)
		var a: Quaternion = first[bone].basis.get_rotation_quaternion()
		var b: Quaternion = last[bone].basis.get_rotation_quaternion()
		degrees = maxf(degrees, rad_to_deg(a.angle_to(b)))
	return {"metres": metres, "degrees": degrees}


## How far a foot slides over the ground in one stride (one play of the
## clip) when the clip plays at `play_speed` while the hero moves at
## `speed` m/s along its facing (+Z). A foot is down while it is within
## CONTACT_BAND of its lowest point in the clip; its slide is how far it
## moves over the ground while down: its own motion at `model_scale`
## plus the ground the hero covers. Returns the worst foot, in metres.
static func foot_slide(anim: Animation, skeleton: Skeleton3D, prefix: String, model_scale: float, speed: float,
		play_speed: float, feet: Array[String] = ["foot.l", "foot.r"]) -> float:
	var samples: int = maxi(8, ceili(anim.length * SAMPLES_PER_SECOND))
	var step: float = anim.length / samples
	var travel_per_step: float = speed * step / maxf(play_speed, 0.001)
	var worst: float = 0.0
	for foot in feet:
		var bone: int = skeleton.find_bone(foot)
		if bone == -1:
			continue
		var points: Array[Vector3] = []
		var lowest: float = INF
		for i in samples + 1:
			var point: Vector3 = pose(anim, skeleton, prefix, i * step)[bone].origin * model_scale
			# Where the foot is on the ground: the hero has moved on by then.
			point.z += travel_per_step * i
			points.append(point)
			lowest = minf(lowest, point.y)
		var slide: float = 0.0
		for i in samples:
			if points[i].y <= lowest + CONTACT_BAND and points[i + 1].y <= lowest + CONTACT_BAND:
				slide += Vector2(points[i + 1].x - points[i].x, points[i + 1].z - points[i].z).length()
		worst = maxf(worst, slide)
	return worst


static func _is_control(bone_name: String) -> bool:
	for marker in CONTROL_MARKERS:
		if bone_name.contains(marker):
			return true
	return false
