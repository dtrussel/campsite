extends Node

## render_icons.gd
##
## Renders UI icons and character portraits from the 3D models into
## res://assets/icons/*.png, so the HUD uses the same art as the world.
## Needs a real renderer (not --headless). From the repo root:
##
##   xvfb-run -a godot --path game --rendering-driver opengl3 \
##       res://tools/render_icons.tscn
##
## The PNGs are committed; re-run only when the art changes.

const OUT_DIR: String = "res://assets/icons/"
const SIZE: int = 128
const KAY: String = "res://assets/kaykit/"
const CUSTOM: String = "res://assets/custom/"

var _viewport: SubViewport = null
var _camera: Camera3D = null
var _stage: Node3D = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_setup_stage()
	# name -> [builder Callable, camera distance, camera height, look height, yaw]
	var jobs: Array = [
		["stone", func() -> Node3D: return _custom("rock_a.glb", 1.0), 2.6, 1.6, 0.4, 0.5],
		["berries", _berries, 1.6, 1.0, 0.25, 0.0],
		["fiber", _fiber, 1.8, 1.0, 0.35, 0.0],
		["leaves", _leaves, 1.6, 1.1, 0.2, 0.0],
		["resin", _resin, 1.4, 0.8, 0.25, 0.0],
		["torch", func() -> Node3D: return _custom("torch.glb", 1.0), 2.4, 1.4, 0.65, 0.4],
		["fence", func() -> Node3D: return _custom("fence.glb", 1.0), 3.0, 1.6, 0.55, 0.35],
		["tower", func() -> Node3D: return _custom("watch_post.glb", 1.0), 5.2, 3.2, 1.35, 0.6],
		["axe", func() -> Node3D: return _prop("adventurers/axe_1handed.gltf", 1.6, Vector3(0, 0, 0.6)), 2.2, 0.4, 0.4, 0.0],
		["campfire", _campfire_custom, 2.9, 2.2, 0.25, 0.3],
		["tent", func() -> Node3D: return _custom("tent.glb", 1.0), 4.6, 2.8, 0.9, 2.3],
		["wood", func() -> Node3D: return _custom("woodpile.glb", 1.0), 2.6, 1.6, 0.25, 0.6],
		["bush", func() -> Node3D: return _custom("berry_bush.glb", 1.0), 2.6, 1.8, 0.4, 0.3],
		["tree", func() -> Node3D: return _custom("tree_a.glb", 1.0), 2.6, 1.2, 0.4, 0.3],
		["pumpkin", func() -> Node3D: return _model("halloween/pumpkin_orange_jackolantern.gltf", 1.0), 2.4, 1.2, 0.6, 0.0],
	]
	for job in jobs:
		await _render(job[0], (job[1] as Callable).call(), job[2], job[3], job[4], job[5])
	# Portraits: head-and-shoulders of each character.
	await _portrait("portrait_leo", "custom/leo.glb", "hero", ["Leo_Stick"], 0.48, 2.4)
	await _portrait("portrait_nela", "custom/nela.glb", "hero", ["Nela_Lantern", "Nela_LanternGlow"], 0.16, 2.7)
	await _portrait("portrait_imp", "custom/shadow_imp.glb", "shadow", [], -0.12, 3.1)
	print("render_icons: done")
	get_tree().quit()


func _setup_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	add_child(_viewport)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.85)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 30, 0)
	key.light_energy = 1.2
	_viewport.add_child(key)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.8
	rim.light_color = Color(1.0, 0.85, 0.6)
	_viewport.add_child(rim)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_viewport.add_child(_camera)
	_stage = Node3D.new()
	_viewport.add_child(_stage)


func _render(name: String, subject: Node3D, _distance: float, height: float, _look_y: float, yaw: float) -> void:
	for child in _stage.get_children():
		child.queue_free()
	subject.rotation.y = yaw
	_stage.add_child(subject)
	await RenderingServer.frame_post_draw
	# Frame the subject from its bounds: look at the centre, back off
	# until the bounding sphere fits the field of view.
	var bounds: AABB = _bounds(subject)
	var center: Vector3 = bounds.get_center()
	var radius: float = bounds.size.length() * 0.5
	var direction: Vector3 = Vector3(0.0, clampf(height / 2.5, 0.2, 0.9), 1.0).normalized()
	var fit: float = radius / tan(deg_to_rad(_camera.fov * 0.5)) * 1.02
	_camera.position = center + direction * fit
	_camera.look_at(center)
	for i in range(4):
		await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT_DIR + name + ".png"))
	print("render_icons: ", name)


func _bounds(root: Node) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh != null and mesh.mesh != null and mesh.is_visible_in_tree():
			var box: AABB = mesh.global_transform * mesh.mesh.get_aabb()
			result = box if first else result.merge(box)
			first = false
		stack.append_array(node.get_children())
	return result


func _portrait(name: String, path: String, style: String, hidden: Array, raise: float = 0.0, distance: float = 2.6) -> void:
	var visual: CharacterVisual = CharacterVisual.new()
	visual.model_scene = load("res://assets/" + path)
	visual.model_scale = 1.0
	visual.hidden_parts = PackedStringArray(hidden)
	visual.style = style
	visual.rotation.y = 0.35 if distance < 3.0 else 0.15
	for child in _stage.get_children():
		child.queue_free()
	_stage.add_child(visual)
	_camera.position = Vector3(0.0, 1.95 + raise, distance)
	_camera.look_at(Vector3(0, 1.62 + raise, 0))
	for i in range(6):
		await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT_DIR + name + ".png"))
	print("render_icons: ", name)


func _custom(file: String, uniform_scale: float) -> Node3D:
	var node: Node3D = (load(CUSTOM + file) as PackedScene).instantiate() as Node3D
	node.scale = Vector3.ONE * uniform_scale
	Stylize.apply(node, "prop")
	return node


func _campfire_custom() -> Node3D:
	var root: Node3D = _custom("campfire.glb", 1.0)
	var flame: MeshInstance3D = _sphere(0.26, Color(1.0, 0.55, 0.15), Vector3(0, 0.5, 0), 2.5)
	flame.scale = Vector3(1.0, 1.8, 1.0)
	root.add_child(flame)
	root.add_child(_sphere(0.15, Color(1.0, 0.9, 0.5), Vector3(0, 0.45, 0.12), 3.0))
	return root


func _model(path: String, uniform_scale: float, tint: Color = Color.WHITE) -> Node3D:
	var node: Node3D = (load(KAY + path) as PackedScene).instantiate() as Node3D
	node.scale = Vector3.ONE * uniform_scale
	if tint != Color.WHITE:
		node.set_meta(Stylize.TINT_META, tint)
	Stylize.apply(node, "prop")
	return node


func _prop(path: String, uniform_scale: float, rotation_rad: Vector3) -> Node3D:
	var holder: Node3D = Node3D.new()
	var node: Node3D = _model(path, uniform_scale)
	node.rotation = rotation_rad
	holder.add_child(node)
	return holder


func _material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	material.rim_enabled = true
	material.rim = 0.5
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material


func _sphere(radius: float, color: Color, position: Vector3, emission: float = 0.0) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh.mesh = sphere
	mesh.material_override = _material(color, emission)
	mesh.position = position
	return mesh


func _berries() -> Node3D:
	var root: Node3D = Node3D.new()
	var spots: Array = [Vector3(0, 0.15, 0), Vector3(0.2, 0.12, 0.05), Vector3(-0.18, 0.12, 0.08),
		Vector3(0.05, 0.3, 0.02), Vector3(-0.08, 0.12, -0.16), Vector3(0.12, 0.12, -0.15)]
	for p in spots:
		root.add_child(_sphere(0.12, Color(0.9, 0.12, 0.28), p, 0.2))
	root.add_child(_sphere(0.1, Color(0.3, 0.65, 0.25), Vector3(0.0, 0.42, -0.02)))
	return root


func _leaves() -> Node3D:
	var root: Node3D = Node3D.new()
	for i in range(5):
		var leaf: MeshInstance3D = _sphere(0.22, Color(0.42, 0.72, 0.28).lerp(Color(0.9, 0.62, 0.2), i * 0.12),
			Vector3(cos(i * 1.3) * 0.15, 0.1 + i * 0.05, sin(i * 1.3) * 0.15))
		leaf.scale = Vector3(1.0, 0.25, 0.55)
		leaf.rotation = Vector3(0.3, i * 1.3, 0.2)
		root.add_child(leaf)
	return root


func _fiber() -> Node3D:
	var root: Node3D = Node3D.new()
	for i in range(9):
		var blade: MeshInstance3D = MeshInstance3D.new()
		var cylinder: CylinderMesh = CylinderMesh.new()
		cylinder.top_radius = 0.012
		cylinder.bottom_radius = 0.03
		cylinder.height = 0.75
		blade.mesh = cylinder
		blade.material_override = _material(Color(0.62, 0.72, 0.3).lerp(Color(0.85, 0.8, 0.45), float(i) / 9.0))
		blade.position = Vector3((i - 4) * 0.025, 0.35, 0)
		blade.rotation.z = (i - 4) * 0.09
		root.add_child(blade)
	var tie: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.1
	torus.outer_radius = 0.14
	tie.mesh = torus
	tie.material_override = _material(Color(0.55, 0.35, 0.2))
	tie.position = Vector3(0, 0.3, 0)
	root.add_child(tie)
	return root


func _resin() -> Node3D:
	var root: Node3D = Node3D.new()
	var drop: MeshInstance3D = _sphere(0.22, Color(1.0, 0.62, 0.12), Vector3(0, 0.22, 0), 0.5)
	drop.scale = Vector3(1.0, 1.25, 1.0)
	root.add_child(drop)
	root.add_child(_sphere(0.1, Color(1.0, 0.8, 0.3), Vector3(0.18, 0.1, 0.1), 0.5))
	return root


func _campfire() -> Node3D:
	var root: Node3D = Node3D.new()
	for i in range(8):
		var angle: float = TAU * i / 8.0
		var rock: Node3D = _model("hexagon/rock_single_C.gltf", 1.5, Color(0.75, 0.74, 0.78))
		rock.position = Vector3(cos(angle) * 0.55, 0, sin(angle) * 0.55)
		root.add_child(rock)
	var flame: MeshInstance3D = _sphere(0.28, Color(1.0, 0.55, 0.15), Vector3(0, 0.35, 0), 2.5)
	flame.scale = Vector3(1.0, 1.7, 1.0)
	root.add_child(flame)
	root.add_child(_sphere(0.16, Color(1.0, 0.9, 0.5), Vector3(0, 0.3, 0.12), 3.0))
	return root
