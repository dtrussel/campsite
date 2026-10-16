extends Node

## model_gallery.gd
##
## Renders each custom model in the game's own look (Stylize materials,
## day sun, ambient and the post grade with the blur off), for before and
## after reviews of the art scripts. Two views per model: the gameplay
## camera angle and a closer, lower 3/4 view. From the repo root:
##
##   xvfb-run -a godot --path game --resolution 960x540 \
##       res://tools/model_gallery.tscn -- <out_dir> [model ...]
##
## Model names are files in res://assets/custom/ without ".glb". With no
## names it renders every model there. Writes <out_dir>/<name>_game.png
## and <out_dir>/<name>_close.png.

const CUSTOM: String = "res://assets/custom/"
const POST_SHADER: Shader = preload("res://shaders/post_tiltshift.gdshader")
const CHARACTERS: Dictionary = {
	"leo": "hero", "nela": "hero",
	"shadow_imp": "shadow", "bramble_beast": "shadow", "mushroom_gremlin": "shadow",
}
const TINT_ROCK: Array[String] = ["rock_"]
const TINT_FOLIAGE: Array[String] = ["hill_", "mountain_"]

var _camera: Camera3D = null
var _stage: Node3D = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("model_gallery: pass an output directory after --")
		get_tree().quit(1)
		return
	var out_dir: String = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var names: Array[String] = []
	for i in range(1, args.size()):
		names.append(args[i])
	if names.is_empty():
		for file in DirAccess.get_files_at(CUSTOM):
			if file.ends_with(".glb"):
				names.append(file.get_basename())
	_setup_stage()
	for model in names:
		await _render(model, out_dir)
	get_tree().quit()


func _setup_stage() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.38, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.5, 0.4)
	env.ambient_light_energy = 0.16
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.tonemap_white = 2.2
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_strength = 0.8
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.15
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.1
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, 35, 0)
	sun.light_color = Color(1.0, 0.84, 0.6)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_blur = 1.0
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	# Grass-green ground, so contact shade and cast shadows read.
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var ground_mat: StandardMaterial3D = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.4, 0.5, 0.24)
	ground_mat.roughness = 1.0
	ground.material_override = ground_mat
	add_child(ground)
	_camera = Camera3D.new()
	_camera.fov = 34.0
	add_child(_camera)
	_stage = Node3D.new()
	add_child(_stage)
	var layer: CanvasLayer = CanvasLayer.new()
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var post: ShaderMaterial = ShaderMaterial.new()
	post.shader = POST_SHADER
	post.set_shader_parameter("blur_enabled", 0.0)
	rect.material = post
	layer.add_child(rect)
	add_child(layer)


func _render(model: String, out_dir: String) -> void:
	var scene: PackedScene = load(CUSTOM + model + ".glb") as PackedScene
	if scene == null:
		push_warning("model_gallery: missing %s" % model)
		return
	var node: Node3D = scene.instantiate() as Node3D
	for prefix in TINT_ROCK:
		if model.begins_with(prefix):
			node.set_meta(Stylize.TINT_META, Stylize.TINT_ROCK)
	for prefix in TINT_FOLIAGE:
		if model.begins_with(prefix):
			node.set_meta(Stylize.TINT_META, Stylize.TINT_FOLIAGE)
	if (model.contains("tree_") or model.contains("pine_") or model.contains("bush") or model.begins_with("mushrooms")) \
			and not model.contains("dead"):
		node.set_meta(Stylize.FOLIAGE_META, true)
	_stage.add_child(node)
	Stylize.apply(node, CHARACTERS.get(model, "prop"))
	var player: AnimationPlayer = node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		for clip in player.get_animation_list():
			if clip.to_lower().ends_with("idle"):
				player.play(clip)
				break
	await get_tree().process_frame
	var box: AABB = _bounds(node)
	var center: Vector3 = box.get_center()
	var radius: float = maxf(box.size.length() * 0.5, 0.3)
	var fit: float = radius / tan(deg_to_rad(_camera.fov * 0.5)) * 0.82
	# The gameplay camera: pitch -52, yaw 35; then a lower, closer 3/4 view.
	for view in [["game", -52.0, 35.0], ["close", -24.0, 30.0]]:
		var pitch: float = deg_to_rad(view[1])
		var yaw: float = deg_to_rad(view[2])
		var direction: Vector3 = Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
		_camera.position = center + direction * fit
		_camera.look_at(center)
		for i in range(4):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png(out_dir.path_join("%s_%s.png" % [model, view[0]]))
	node.queue_free()
	await get_tree().process_frame
	print("model_gallery: ", model)


func _bounds(root: Node) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
