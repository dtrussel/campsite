extends Node

## hero_capture.gd
##
## Records a hero playing a list of states in the game's own look (the
## CharacterVisual the role shells use, Stylize materials, a day sun),
## from the gameplay camera's pitch, north-up, and writes one PNG strip
## per state: STRIP_FRAMES frames spread evenly over the clip, left to
## right. Walk and run travel east over a checked ground at the role's
## speed, so a sliding foot shows. Every capture frames the same way,
## so an old strip and a new one can be stacked to compare. From the
## repo root:
##
##   xvfb-run -a godot --path game --resolution 320x180 --fixed-fps 30 \
##       res://tools/hero_capture.tscn -- <out_dir> <hero> [state ...] [options]
##
## States are the hero's logical states (idle, walk, move, attack, ...,
## or a fidget such as fidget_look); with none it records every state
## the hero maps, its fidgets last. Two motions show the spring chains
## (hair, pack): `turn` (running east, a sudden turn back west) and
## `stop` (running east, then standing). Options:
##   --role player|companion   one role only (both by default); the
##                             roles differ in speeds (attack, gather, run)
##   --all-frames              also writes every frame to
##                             <out_dir>/<hero>_<role>_<state>/NNN.png,
##                             for a GIF:
##                             ffmpeg -framerate 30 -i <dir>/%03d.png <dir>.gif
##   --stack <old_dir> <new_dir> <out_dir>
##                             puts each strip in <old_dir> above the one
##                             of the same name in <new_dir> (no capture)
##
## Writes <out_dir>/<hero>_<role>_<state>.png. `--fixed-fps 30` makes
## every frame 1/30 s of game time, however slowly it renders.

const ClipChecks: GDScript = preload("res://tools/clip_checks.gd")
const STRIP_FRAMES: int = 8
## The frame rate the capture runs at (--fixed-fps).
const FPS: int = 30
## The gameplay camera's pitch (CameraFollow) and lens, closer in.
const PITCH_DEGREES: float = 42.0
const FOV: float = 34.0
const DISTANCE: float = 3.2
const STATES: Array[StringName] = [&"idle", &"walk", &"move", &"attack", &"hit", &"cheer", &"gather", &"chop",
	&"pick", &"tinker", &"hammer", &"death", &"getup"]
## Where the companion plays a state at another speed than the player
## (companion_controller.gd).
const COMPANION_SPEEDS: Dictionary = {&"attack": 1.45, &"gather": 1.3}
## Game seconds to settle into a state before recording it.
const SETTLE_SECONDS: float = 0.6
## Motions that are not clips: how long each records after its change.
const MOTIONS: Dictionary = {&"turn": 1.2, &"stop": 1.2}

var _camera: Camera3D = null
var _stage: Node3D = null
var _visual: CharacterVisual = null
var _speed: float = 0.0
## The way the visual travels (and, while _turning, turns toward).
var _heading: Vector3 = Vector3.RIGHT
var _turning: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var stack: int = args.find("--stack")
	if stack != -1:
		if args.size() < stack + 4:
			_quit_with("hero_capture: --stack needs <old_dir> <new_dir> <out_dir>")
			return
		_stack(args[stack + 1], args[stack + 2], args[stack + 3])
		get_tree().quit()
		return
	var role_at: int = args.find("--role")
	var roles: Array[String] = ["player", "companion"]
	if role_at != -1 and role_at + 1 < args.size():
		roles = [args[role_at + 1]]
	var all_frames: bool = args.has("--all-frames")
	var plain: Array[String] = []
	for i in args.size():
		if args[i].begins_with("--") or (i > 0 and args[i - 1] == "--role"):
			continue
		plain.append(args[i])
	if plain.size() < 2:
		_quit_with("hero_capture: pass <out_dir> <hero> [state ...] after --")
		return
	# --fixed-fps is the engine's own, so it is not in the arguments:
	# check that frames are 1/FPS s apart instead.
	await get_tree().process_frame
	await get_tree().process_frame
	if absf(get_process_delta_time() - 1.0 / FPS) > 0.0001:
		_quit_with("hero_capture: run with --fixed-fps 30, so frames are even in game time")
		return
	var hero: HeroDefinition = HeroRoster.get_hero(StringName(plain[1]))
	if hero == null:
		_quit_with("hero_capture: no hero '%s'" % plain[1])
		return
	var states: Array[StringName] = []
	for i in range(2, plain.size()):
		states.append(StringName(plain[i]))
	if states.is_empty():
		states = STATES.filter(func(state: StringName) -> bool: return hero.clips.has(state))
		states.append_array(hero.fidgets)
	DirAccess.make_dir_recursive_absolute(plain[0])
	_setup_stage()
	for role in roles:
		for state in states:
			await _record(hero, role, state, plain[0], all_frames)
	get_tree().quit()


func _quit_with(message: String) -> void:
	printerr(message)
	get_tree().quit(1)


func _physics_process(delta: float) -> void:
	if _visual == null:
		return
	_visual.set_locomotion(_speed)
	if _turning:
		_visual.face(_heading, delta)
	if _speed > 0.0:
		_visual.global_position += _heading * _speed * delta
	_camera.global_position = _visual.global_position + Vector3(0.0, 0.6, 0.0) \
		+ Vector3(0.0, sin(deg_to_rad(PITCH_DEGREES)), cos(deg_to_rad(PITCH_DEGREES))) * DISTANCE


## Plays `state` as `role` on a fresh visual and writes its strip.
func _record(hero: HeroDefinition, role: String, state: StringName, out_dir: String, all_frames: bool) -> void:
	var name: String = "%s_%s_%s" % [hero.id, role, state]
	_visual = _make_visual(hero)
	_stage.add_child(_visual)
	var travels: bool = state == &"walk" or state == &"move" or MOTIONS.has(state)
	_visual.face_instantly(Vector3.RIGHT if travels else Vector3(0.3, 0, 1))
	_heading = Vector3.RIGHT
	_turning = false
	_speed = 0.0
	if state == &"walk":
		_speed = _visual.walk_speed
	elif state == &"move" or MOTIONS.has(state):
		_speed = hero.move_speed if role == "player" else hero.companion_move_speed
	if state == &"hammer" or state == &"tinker":
		# The build beat keeps the mallet out for its fiddling beat too.
		_visual.show_tool(&"hammer")
	await _wait(SETTLE_SECONDS)
	var seconds: float = 0.0
	if state == &"turn":
		_heading = Vector3.LEFT
		_turning = true
		seconds = MOTIONS[state]
	elif state == &"stop":
		_speed = 0.0
		seconds = MOTIONS[state]
	elif state == &"idle" or state == &"walk" or state == &"move":
		var clip: Animation = _clip(hero, state)
		var play: float = 1.0
		if state == &"walk":
			play = CharacterVisual.walk_play_speed(_speed, hero.walk_reference_speed)
		elif state == &"move":
			play = CharacterVisual.run_play_speed(_speed, hero.reference_speed)
		seconds = clip.length / play if clip != null else 1.0
	elif state == &"death":
		seconds = _visual.play_final(state)
	elif state == &"getup":
		# As in the game: from the held down pose (Hero._set_down).
		await _wait(_visual.play_final(&"death") + 0.3)
		_visual.unlock(&"getup")
		seconds = _clip(hero, state).length if _clip(hero, state) != null else 1.0
	else:
		var speed: float = float(COMPANION_SPEEDS.get(state, ClipChecks.PLAY_SPEEDS.get(state, 1.0))) \
			if role == "companion" else float(ClipChecks.PLAY_SPEEDS.get(state, 1.0))
		seconds = _visual.play_action(state, speed)
	var frames: Array[Image] = []
	var ticks: int = maxi(1, roundi(seconds * FPS))
	for i in ticks:
		await RenderingServer.frame_post_draw
		frames.append(get_viewport().get_texture().get_image())
	_write_strip(frames, out_dir.path_join(name + ".png"))
	if all_frames:
		var dir: String = out_dir.path_join(name)
		DirAccess.make_dir_recursive_absolute(dir)
		for i in frames.size():
			frames[i].save_png(dir.path_join("%03d.png" % i))
	_visual.queue_free()
	_visual = null
	await get_tree().process_frame
	print("hero_capture: ", name, " (%.2f s, %d frames)" % [seconds, frames.size()])


func _make_visual(hero: HeroDefinition) -> CharacterVisual:
	var shell: Node3D = Node3D.new()
	var visual: CharacterVisual = CharacterVisual.new()
	visual.name = "Visual"
	visual.style = "hero"
	shell.add_child(visual)
	HeroBody.apply(shell, hero)
	shell.remove_child(visual)
	shell.free()
	return visual


func _clip(hero: HeroDefinition, state: StringName) -> Animation:
	var player: AnimationPlayer = _visual.model.find_child("AnimationPlayer", true, false) as AnimationPlayer \
		if _visual.model != null else null
	var clip: String = String(hero.clips.get(state, ""))
	return player.get_animation(clip) if player != null and player.has_animation(clip) else null


func _wait(seconds: float) -> void:
	var frames: int = maxi(1, roundi(seconds * FPS))
	for i in frames:
		await get_tree().process_frame


## STRIP_FRAMES of `frames`, evenly spread from the first to the last.
func _write_strip(frames: Array[Image], path: String) -> void:
	if frames.is_empty():
		return
	var w: int = frames[0].get_width()
	var h: int = frames[0].get_height()
	var strip: Image = Image.create(w * STRIP_FRAMES, h, false, frames[0].get_format())
	for i in STRIP_FRAMES:
		var at: int = roundi(float(i) * (frames.size() - 1) / maxf(STRIP_FRAMES - 1, 1))
		strip.blit_rect(frames[at], Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	strip.save_png(path)


func _stack(old_dir: String, new_dir: String, out_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	for file in DirAccess.get_files_at(old_dir):
		if not file.ends_with(".png") or not FileAccess.file_exists(new_dir.path_join(file)):
			continue
		var top: Image = Image.load_from_file(old_dir.path_join(file))
		var bottom: Image = Image.load_from_file(new_dir.path_join(file))
		bottom.convert(top.get_format())
		var both: Image = Image.create(maxi(top.get_width(), bottom.get_width()), top.get_height() + bottom.get_height(),
			false, top.get_format())
		both.blit_rect(top, Rect2i(Vector2i.ZERO, top.get_size()), Vector2i.ZERO)
		both.blit_rect(bottom, Rect2i(Vector2i.ZERO, bottom.get_size()), Vector2i(0, top.get_height()))
		both.save_png(out_dir.path_join(file))
		print("hero_capture: stacked ", file)


func _setup_stage() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.38, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.5, 0.4)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.tonemap_white = 2.2
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, 35, 0)
	sun.light_color = Color(1.0, 0.84, 0.6)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)
	# A checked ground (half-metre squares), so a sliding foot shows.
	var checker: Image = Image.create(2, 2, false, Image.FORMAT_RGB8)
	checker.fill(Color(0.42, 0.52, 0.26))
	checker.set_pixel(0, 0, Color(0.34, 0.44, 0.2))
	checker.set_pixel(1, 1, Color(0.34, 0.44, 0.2))
	var ground_mat: StandardMaterial3D = StandardMaterial3D.new()
	ground_mat.albedo_texture = ImageTexture.create_from_image(checker)
	ground_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ground_mat.uv1_scale = Vector3(200, 200, 1)
	ground_mat.roughness = 1.0
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(200, 200)
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = ground_mat
	add_child(ground)
	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.rotation = Vector3(-deg_to_rad(PITCH_DEGREES), 0.0, 0.0)
	add_child(_camera)
	_stage = Node3D.new()
	add_child(_stage)
