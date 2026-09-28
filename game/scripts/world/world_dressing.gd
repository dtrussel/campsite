extends Node3D

## WorldDressing
##
## Builds the non-interactive art around the play area at load time,
## deterministically (fixed seed), so the map looks hand-dressed without
## hundreds of hand-placed nodes:
##   - a grass field (one MultiMesh, wind-animated, with a few flowers),
##   - a dense forest border that frames the arena,
##   - a spooky edge (dead trees, jack-o'-lanterns) near the mob spawns,
##   - camp props around the campfire (tent, woodpile, crates, lanterns).
## Nothing here affects gameplay except the tent and woodpile colliders.

const KAY: String = "res://assets/kaykit/"
const GRASS_SHADER: Shader = preload("res://shaders/grass.gdshader")

@export var dressing_seed: int = 1337
@export var grass_count: int = 3200
@export var grass_extent: float = 24.0
@export var clearing_radius: float = 4.6
@export var border_inner: float = 21.5
@export var border_outer: float = 36.0
## Mob spawn directions (degrees) get the haunted props.
@export var spawn_angles: PackedFloat32Array = PackedFloat32Array([0.0, 90.0, 180.0, 270.0])

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _keep_out: Array = []  # [Vector2 center, float radius]
var _scene_cache: Dictionary = {}


func _ready() -> void:
	_rng.seed = dressing_seed
	_collect_keep_out()
	_build_grass()
	_build_border()
	_build_haunted_edges()
	_build_camp()


# --- Grass ---------------------------------------------------------------

func _build_grass() -> void:
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _make_tuft_mesh()
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var attempts: int = 0
	while transforms.size() < grass_count and attempts < grass_count * 4:
		attempts += 1
		var p: Vector2 = Vector2(_rng.randf_range(-grass_extent, grass_extent), _rng.randf_range(-grass_extent, grass_extent))
		# Denser toward the edges, sparse in the worn camp area.
		var r: float = p.length()
		if r < clearing_radius + _rng.randf_range(-0.3, 1.2):
			continue
		if r < 8.0 and _rng.randf() < 0.45:
			continue
		if _blocked(p, 0.2):
			continue
		var s: float = _rng.randf_range(0.7, 1.35)
		var basis: Basis = Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.3), s))
		transforms.append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
		colors.append(_tuft_color())
	multimesh.instance_count = transforms.size()
	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, colors[i])
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = "Grass"
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = GRASS_SHADER
	instance.material_override = material
	add_child(instance)


func _tuft_color() -> Color:
	var roll: float = _rng.randf()
	if roll < 0.025:
		return Color(1.0, 0.86, 0.3)   # buttercup
	if roll < 0.04:
		return Color(0.95, 0.95, 1.0)  # daisy
	if roll < 0.055:
		return Color(0.85, 0.5, 0.95)  # violet
	var g: float = _rng.randf()
	return Color(0.46, 0.68, 0.26).lerp(Color(0.66, 0.8, 0.34), g)


## Three crossed, tapering blades (about 0.45 m tall).
func _make_tuft_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(3):
		var angle: float = TAU * float(i) / 3.0 + 0.3
		var side: Vector3 = Vector3(cos(angle), 0, sin(angle)) * 0.13
		var lean: Vector3 = Vector3(-sin(angle), 0, cos(angle)) * 0.06
		var a: Vector3 = -side
		var b: Vector3 = side
		var c: Vector3 = side * 0.55 + Vector3(0, 0.2, 0) + lean * 0.5
		var d: Vector3 = -side * 0.55 + Vector3(0, 0.2, 0) + lean * 0.5
		var tip: Vector3 = Vector3(0, 0.38, 0) + lean
		for v in [a, b, c, a, c, d, d, c, tip]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()


# --- Forest border ---------------------------------------------------------

func _build_border() -> void:
	var near_models: Array = [
		["custom/tree_a.glb", 0.85, 1.1],
		["custom/tree_b.glb", 0.85, 1.1],
		["custom/tree_c.glb", 0.85, 1.1],
		["custom/pine_a.glb", 0.8, 1.05],
		["custom/pine_b.glb", 0.8, 1.05],
	]
	var far_models: Array = [
		["custom/tree_a.glb", 1.1, 1.5],
		["custom/tree_b.glb", 1.1, 1.5],
		["custom/tree_c.glb", 1.1, 1.5],
		["custom/pine_b.glb", 1.1, 1.4],
		["kaykit/hexagon/hills_A_trees.gltf", 4.5, 6.0],
		["kaykit/hexagon/hills_B_trees.gltf", 4.5, 6.0],
	]
	var backdrop: Array = [
		["kaykit/hexagon/mountain_A_grass_trees.gltf", 7.0, 9.0],
		["kaykit/hexagon/mountain_B_grass_trees.gltf", 7.0, 9.0],
		["kaykit/hexagon/hills_C_trees.gltf", 6.0, 8.0],
	]
	# Inner ring: individual trees just past the play boundary.
	for i in range(70):
		var angle: float = _rng.randf() * TAU
		var r: float = _rng.randf_range(border_inner - 1.5, border_inner + 3.0)
		_place_square_ring(near_models, angle, r)
	# Middle ring: tree clusters.
	for i in range(60):
		var angle: float = _rng.randf() * TAU
		_place_square_ring(far_models, angle, _rng.randf_range(border_inner + 3.0, border_outer - 6.0))
	# Backdrop: hills and mountains to close the horizon.
	for i in range(26):
		var angle: float = TAU * float(i) / 26.0 + _rng.randf_range(-0.08, 0.08)
		_place_square_ring(backdrop, angle, _rng.randf_range(border_outer - 4.0, border_outer + 4.0))


## Places a random model from `models` on a rounded square ring so the
## border follows the square play area.
func _place_square_ring(models: Array, angle: float, radius: float) -> void:
	var dir: Vector2 = Vector2(cos(angle), sin(angle))
	var squareness: float = maxf(absf(dir.x), absf(dir.y))
	var p: Vector2 = dir / squareness * radius * 0.92
	var pick: Array = models[_rng.randi() % models.size()]
	_spawn_model(pick[0], Vector3(p.x, 0.0, p.y), _rng.randf_range(pick[1], pick[2]), _rng.randf() * TAU)


# --- Haunted edges near mob spawns ---------------------------------------

func _build_haunted_edges() -> void:
	var dead: Array = ["kaykit/halloween/tree_dead_large.gltf", "kaykit/halloween/tree_dead_medium.gltf", "kaykit/halloween/tree_dead_small.gltf"]
	for spawn_angle in spawn_angles:
		var base: float = deg_to_rad(spawn_angle)
		var dir: Vector3 = Vector3(sin(base), 0, -cos(base))
		var side: Vector3 = Vector3(-dir.z, 0, dir.x)
		for i in range(5):
			var along: float = _rng.randf_range(17.5, 23.0)
			var offset: float = _rng.randf_range(2.0, 6.0) * (1.0 if i % 2 == 0 else -1.0)
			var pos: Vector3 = dir * along + side * offset
			_spawn_model(dead[_rng.randi() % dead.size()], pos, _rng.randf_range(0.9, 1.3), _rng.randf() * TAU)
		# A glowing jack-o'-lantern marks each lane.
		var lantern_pos: Vector3 = dir * 18.5 + side * _rng.randf_range(2.5, 3.5)
		var pumpkin: Node3D = _spawn_model("kaykit/halloween/pumpkin_orange_jackolantern.gltf", lantern_pos, 0.8, _rng.randf() * TAU)
		if pumpkin != null:
			var glow: OmniLight3D = OmniLight3D.new()
			glow.light_color = Color(1.0, 0.5, 0.15)
			glow.light_energy = 1.2
			glow.omni_range = 3.5
			glow.position = Vector3(0, 0.6, 0)
			pumpkin.add_child(glow)
		_spawn_model("kaykit/halloween/pumpkin_yellow_small.gltf", lantern_pos + side * 0.9 + dir * 0.4, 1.0, _rng.randf() * TAU)


# --- Camp ------------------------------------------------------------------

func _build_camp() -> void:
	var tent: Node3D = _spawn_model("custom/tent.glb", Vector3(-3.4, 0, -2.7), 1.25, deg_to_rad(125.0))
	_add_blocker(tent, Vector3(2.8, 2.0, 2.4))
	var logs: Node3D = _spawn_model("custom/woodpile.glb", Vector3(3.0, 0, -2.5), 1.0, deg_to_rad(-25.0))
	_add_blocker(logs, Vector3(1.3, 0.8, 0.8))
	_spawn_model("custom/crate.glb", Vector3(-5.3, 0, -0.8), 0.9, 0.4)
	_spawn_model("custom/crate.glb", Vector3(-4.7, 0, 0.1), 0.65, 1.1)
	_spawn_model("custom/barrel.glb", Vector3(-5.8, 0, 0.5), 0.9, 0.0)
	_spawn_model("kaykit/hexagon/bucket_water.gltf", Vector3(1.6, 0, -3.6), 4.5, 0.0)
	for pos in [Vector3(-2.1, 0, 2.9), Vector3(3.1, 0, 1.2)]:
		var lantern: Node3D = _spawn_model("kaykit/halloween/lantern_standing.gltf", pos, 0.9, _rng.randf() * TAU)
		if lantern != null:
			var light: OmniLight3D = OmniLight3D.new()
			light.light_color = Color(1.0, 0.75, 0.4)
			light.light_energy = 0.9
			light.omni_range = 4.0
			light.position = Vector3(0, 0.75, 0)
			lantern.add_child(light)
	# Toadstool clusters dotted around the clearing edge and forest.
	for i in range(14):
		var angle: float = _rng.randf() * TAU
		var r: float = _rng.randf_range(6.0, 19.0)
		var p: Vector2 = Vector2(cos(angle), sin(angle)) * r
		if _blocked(p, 0.8):
			continue
		_spawn_model("custom/toadstools.glb", Vector3(p.x, 0, p.y), _rng.randf_range(0.7, 1.2), _rng.randf() * TAU)
	# A few loose boulders for texture.
	for i in range(8):
		var angle2: float = _rng.randf() * TAU
		var p2: Vector2 = Vector2(cos(angle2), sin(angle2)) * _rng.randf_range(9.0, 19.0)
		if _blocked(p2, 1.2):
			continue
		var rock: String = ["custom/rock_a.glb", "custom/rock_b.glb", "custom/rock_c.glb"][_rng.randi() % 3]
		_spawn_model(rock, Vector3(p2.x, 0, p2.y), _rng.randf_range(0.5, 0.9), _rng.randf() * TAU)


# --- Helpers -----------------------------------------------------------------

func _collect_keep_out() -> void:
	var root: Node = get_parent()
	for node in root.find_children("*", "ResourceNode", true, false):
		var n3d: Node3D = node as Node3D
		_keep_out.append([Vector2(n3d.position.x, n3d.position.z), 1.1])


func _blocked(p: Vector2, margin: float) -> bool:
	for zone in _keep_out:
		if p.distance_to(zone[0]) < float(zone[1]) + margin:
			return true
	return false


func _spawn_model(path: String, position: Vector3, uniform_scale: float, yaw: float) -> Node3D:
	if not _scene_cache.has(path):
		_scene_cache[path] = load("res://assets/" + path) as PackedScene
	var scene: PackedScene = _scene_cache[path]
	if scene == null:
		push_warning("WorldDressing: missing %s" % path)
		return null
	var node: Node3D = scene.instantiate() as Node3D
	node.position = position
	node.rotation.y = yaw
	node.scale = Vector3.ONE * uniform_scale
	if path.contains("hills") or path.contains("mountain"):
		node.set_meta(Stylize.TINT_META, Stylize.TINT_FOLIAGE)
	elif path.contains("rock"):
		node.set_meta(Stylize.TINT_META, Stylize.TINT_ROCK)
	add_child(node)
	return node


func _add_blocker(owner_node: Node3D, size: Vector3) -> void:
	if owner_node == null:
		return
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 4  # buildings layer: blocks characters, baked into nav
	body.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(shape)
	add_child(body)
	body.global_position = owner_node.global_position
	body.rotation.y = owner_node.rotation.y
