extends Node3D

## WorldDressing
##
## Builds the non-interactive art around the play area at load time,
## deterministically (fixed seed), following the map plan in WorldLayout
## (feature 032): a camp yard in a forest clearing, four themed groves
## in the corners between the mob lanes, footpaths out to them and the
## old road south. It builds:
##   - the painted ground's paths and grove grounds (via WorldLayout),
##   - a grass field (one MultiMesh, wind-animated), wildflower drifts
##     (daisies, buttercups, lupines) thickest in the Berry Hollow,
##     ferns in the shady groves and reeds round the pond,
##   - each grove's dressing and landmark: the giant pine, the pond,
##     the woodcutters' stumps and woodpile, the great oak's fairy ring,
##   - a forest wall that matches the grove behind it, with gaps where
##     the mob lanes come in (dead trees and jack-o'-lanterns there),
##   - the camp props and the feature 031 homestead decor.
## Nothing here affects gameplay except the colliders of the tent,
## woodpile, stall, well and pond. Solid decor stays off the mob lanes.

const GRASS_SHADER: Shader = preload("res://shaders/grass.gdshader")
const WATER_SHADER: Shader = preload("res://shaders/pond_water.gdshader")

@export var dressing_seed: int = 1337
@export var grass_count: int = 3400
@export var grass_extent: float = 24.0
@export var flower_drifts: int = 70
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
	_apply_ground()
	_build_camp()
	_build_groves()
	_build_grass()
	_build_flowers()
	_build_border()
	_build_haunted_edges()


func _apply_ground() -> void:
	var ground: MeshInstance3D = get_parent().get_node_or_null("Ground/GroundMesh") as MeshInstance3D
	if ground == null:
		return
	var material: ShaderMaterial = ground.get_surface_override_material(0) as ShaderMaterial
	if material != null:
		WorldLayout.apply_to_ground(material)


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
		if r < WorldLayout.CAMP_RADIUS + _rng.randf_range(-0.3, 1.2):
			continue
		if r < 8.0 and _rng.randf() < 0.45:
			continue
		if _blocked(p, 0.2) or on_path(p, 0.3) or WorldLayout.in_pond(p, 0.5):
			continue
		# Needle litter under the pines and the trodden lane trails stay thin.
		var zone: WorldLayout.Zone = WorldLayout.zone_at(p)
		if zone == WorldLayout.Zone.PINE_GROVE and _rng.randf() < 0.6:
			continue
		if WorldLayout.in_lane(p, -2.2) and r > 11.0 and _rng.randf() < 0.6:
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
	return Color(0.32, 0.52, 0.18).lerp(Color(0.56, 0.68, 0.26), g)


## Five blades fanning out and curving over (about 0.3-0.45 m
## tall); each blade is three tapering segments, so tufts read as
## painted blades instead of flat cards (feature 031 M6).
func _make_tuft_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 31
	for i in range(5):
		var angle: float = TAU * float(i) / 5.0 + rng.randf_range(-0.3, 0.3)
		var out: Vector3 = Vector3(cos(angle), 0, sin(angle))
		var across: Vector3 = Vector3(-out.z, 0, out.x)
		var height: float = rng.randf_range(0.26, 0.44)
		var bend: float = rng.randf_range(0.08, 0.16)
		var root: Vector3 = out * rng.randf_range(0.0, 0.05)
		var points: Array = []
		for k in range(4):
			var t: float = float(k) / 3.0
			points.append(root + out * bend * t * t + Vector3(0, height * (t - 0.12 * t * t), 0))
		for k in range(3):
			var w0: float = 0.05 * (1.0 - float(k) / 3.5)
			var w1: float = 0.05 * (1.0 - float(k + 1) / 3.5)
			var p0: Vector3 = points[k]
			var p1: Vector3 = points[k + 1]
			var quad: Array = [p0 - across * w0, p0 + across * w0, p1 + across * w1, p1 - across * w1]
			var tris: Array = [quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]] if k < 2 else [quad[0], quad[1], p1]
			for v in tris:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	return st.commit()


## True when `p` (x, z) lies on a footpath or the road (plus `margin`).
func on_path(p: Vector2, margin: float = 0.0) -> bool:
	return WorldLayout.on_path(p, margin)


# --- Wildflowers (feature 031) ---------------------------------------------

const FLOWER_COLORS: Array = [Color(1.0, 0.82, 0.2), Color(1.0, 0.9, 0.35), Color(0.98, 0.97, 0.92)]
const LUPINE_COLORS: Array = [Color(0.6, 0.44, 0.92), Color(0.76, 0.5, 0.9), Color(0.5, 0.42, 0.86)]


## Drifts of flowers: each drift is one colour family, so the meadow reads
## in painted patches like the concept art, thickest around the camp's
## edge and toward the trees.
func _build_flowers() -> void:
	var clumps: Array = [[], []]   # transforms, colors
	var spikes: Array = [[], []]
	for i in range(flower_drifts):
		var center: Vector2 = _drift_centre(i)
		var lupine: bool = _rng.randf() < 0.3
		var target: Array = spikes if lupine else clumps
		var family: Color = (LUPINE_COLORS if lupine else FLOWER_COLORS)[_rng.randi() % 3]
		for k in range(_rng.randi_range(6, 13)):
			var p: Vector2 = center + Vector2(_rng.randfn(0.0, 0.9), _rng.randfn(0.0, 0.9))
			if p.length() < WorldLayout.CAMP_RADIUS + 0.3 or _blocked(p, 0.3) or on_path(p, 0.2) \
					or WorldLayout.in_pond(p, 0.6) or WorldLayout.zone_at(p) == WorldLayout.Zone.PINE_GROVE:
				continue
			var s: float = _rng.randf_range(0.8, 1.25)
			var basis: Basis = Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s))
			target[0].append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
			target[1].append(family.lerp(Color.WHITE, _rng.randf_range(0.0, 0.15)))
	_add_flower_multimesh("Flowers", _make_flower_mesh(), clumps)
	_add_flower_multimesh("Lupines", _make_lupine_mesh(), spikes)


## Drift centres: two in five ring the camp yard, two in five fill the
## Berry Hollow, the rest are spread over the meadow and the woodlot.
func _drift_centre(i: int) -> Vector2:
	if i % 5 == 1 or i % 5 == 3:
		var hollow: Array = WorldLayout.GROVES[3]
		return hollow[1] + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, hollow[2])
	var angle: float = _rng.randf() * TAU
	var radius: float = _rng.randf_range(WorldLayout.CAMP_RADIUS + 0.8, 10.0) if i % 5 == 0 else _rng.randf_range(9.0, 19.0)
	return Vector2(cos(angle), sin(angle)) * radius


func _add_flower_multimesh(node_name: String, mesh: ArrayMesh, data: Array, color_height: float = 0.26,
		wind: float = 0.08) -> void:
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = data[0].size()
	for i in range(data[0].size()):
		multimesh.set_instance_transform(i, data[0][i])
		multimesh.set_instance_color(i, data[1][i])
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = GRASS_SHADER
	material.set_shader_parameter("color_height", color_height)
	material.set_shader_parameter("wind_strength", wind)
	instance.material_override = material
	add_child(instance)


## Four stems, each topped by a shallow cup of five rounded petals
## around a warm centre (about 0.3-0.4 m). Vertex colours multiply the
## instance colour: white petals keep the drift colour, the centre
## goes golden.
func _make_flower_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var heads: Array = [Vector3(0.0, 0.36, 0.0), Vector3(0.12, 0.3, 0.05), Vector3(-0.08, 0.32, 0.11),
		Vector3(-0.04, 0.28, -0.12)]
	var centre_colour: Color = Color(1.0, 0.62, 0.16)
	for head in heads:
		_add_stem(st, Vector3(head.x * 0.6, 0.0, head.z * 0.6), head, 0.012)
		var petal_r: float = 0.075
		for k in range(5):
			var a: float = TAU * float(k) / 5.0
			var dir: Vector3 = Vector3(cos(a), 0.0, sin(a))
			var side: Vector3 = Vector3(-dir.z, 0.0, dir.x)
			# A petal: narrow at the centre, wide and lifted at the rim.
			var base: Vector3 = head + dir * petal_r * 0.18
			var mid_l: Vector3 = head + dir * petal_r * 0.6 + side * petal_r * 0.32 + Vector3(0, 0.012, 0)
			var mid_r: Vector3 = head + dir * petal_r * 0.6 - side * petal_r * 0.32 + Vector3(0, 0.012, 0)
			var tip: Vector3 = head + dir * petal_r + Vector3(0, 0.022, 0)
			for v in [base, mid_r, mid_l, mid_l, mid_r, tip]:
				st.set_color(Color.WHITE)
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		# Raised centre.
		for k in range(5):
			var a0: float = TAU * float(k) / 5.0
			var a1: float = TAU * float(k + 1) / 5.0
			for v in [head + Vector3(0, 0.014, 0), head + Vector3(cos(a1), 0.0, sin(a1)) * petal_r * 0.26,
					head + Vector3(cos(a0), 0.0, sin(a0)) * petal_r * 0.26]:
				st.set_color(centre_colour)
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	return st.commit()


## A stem with a tapering spike of floret tiers on three crossed planes:
## a lupine (~0.65 m). Each tier flares out a little, so the spike reads
## as stacked florets, darker toward the base.
func _make_lupine_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for spike in [Vector3(0.0, 0.0, 0.0), Vector3(0.14, 0.0, 0.06)]:
		var size: float = 1.0 if spike == Vector3.ZERO else 0.75
		_add_stem(st, spike, spike + Vector3(0, 0.3 * size, 0), 0.014)
		var bottom: float = 0.26 * size
		var top: float = 0.68 * size
		var tiers: int = 6
		for side in [Vector3(1, 0, 0), Vector3(0.5, 0, 0.866), Vector3(-0.5, 0, 0.866)]:
			for t in range(tiers):
				var f0: float = float(t) / tiers
				var f1: float = float(t + 1) / tiers
				var y0: float = lerpf(bottom, top, f0)
				var y1: float = lerpf(bottom, top, f1)
				# Flared tier: wide at its bottom, pinched at its top.
				var w0: Vector3 = side * lerpf(0.065, 0.016, f0) * size
				var w1: Vector3 = side * lerpf(0.065, 0.016, f1) * size * 0.55
				var shade: Color = Color.WHITE.darkened(0.25 * (1.0 - f0))
				var a: Vector3 = spike + Vector3(0, y0, 0)
				var b: Vector3 = spike + Vector3(0, y1, 0)
				for v in [a - w0, a + w0, b + w1, a - w0, b + w1, b - w1]:
					st.set_color(shade)
					st.set_normal(Vector3.UP)
					st.add_vertex(v)
	return st.commit()


func _add_stem(st: SurfaceTool, from: Vector3, to: Vector3, width: float) -> void:
	var side: Vector3 = Vector3(width, 0.0, 0.0)
	for v in [from - side, from + side, to + side, from - side, to + side, to - side]:
		st.set_color(Color.WHITE)
		st.set_normal(Vector3.UP)
		st.add_vertex(v)


# --- Forest border ---------------------------------------------------------

const BROADLEAF: Array = ["custom/tree_a.glb", "custom/tree_b.glb", "custom/tree_c.glb"]
const GREEN_PINES: Array = ["custom/pine_c.glb", "custom/pine_d.glb"]
const BOULDERS: Array = ["custom/rock_a.glb", "custom/rock_b.glb", "custom/rock_c.glb"]
const TALL_SOUTH_LIMIT: float = 16.5

## The wall behind each grove matches it: pines behind the Pine Grove,
## pines and boulders behind the pond, broadleaf woods behind the
## Woodlot and the Berry Hollow. [path, min scale, max scale]
const WALL_NEAR: Dictionary = {
	WorldLayout.Zone.PINE_GROVE: [["custom/pine_c.glb", 0.85, 1.15], ["custom/pine_d.glb", 0.85, 1.15],
		["custom/pine_c.glb", 0.9, 1.2], ["custom/tree_c.glb", 0.85, 1.05]],
	WorldLayout.Zone.STONY_POND: [["custom/pine_c.glb", 0.85, 1.15], ["custom/pine_d.glb", 0.85, 1.15],
		["custom/rock_a.glb", 1.3, 2.0], ["custom/rock_b.glb", 1.3, 2.0], ["custom/tree_a.glb", 0.85, 1.05]],
	WorldLayout.Zone.WOODLOT: [["custom/tree_a.glb", 0.85, 1.15], ["custom/tree_b.glb", 0.85, 1.15],
		["custom/tree_c.glb", 0.85, 1.15], ["custom/pine_d.glb", 0.85, 1.0]],
	WorldLayout.Zone.BERRY_HOLLOW: [["custom/tree_a.glb", 0.85, 1.15], ["custom/tree_b.glb", 0.85, 1.15],
		["custom/tree_c.glb", 0.85, 1.15], ["custom/flower_bush.glb", 0.9, 1.3]],
}
const WALL_FAR: Dictionary = {
	WorldLayout.Zone.PINE_GROVE: [["custom/pine_c.glb", 1.1, 1.5], ["custom/pine_d.glb", 1.1, 1.5],
		["custom/hill_a.glb", 4.5, 6.0]],
	WorldLayout.Zone.STONY_POND: [["custom/pine_c.glb", 1.1, 1.5], ["custom/pine_d.glb", 1.1, 1.5],
		["custom/rock_b.glb", 2.2, 3.2], ["custom/hill_b.glb", 4.5, 6.0]],
	WorldLayout.Zone.WOODLOT: [["custom/tree_a.glb", 1.1, 1.5], ["custom/tree_b.glb", 1.1, 1.5],
		["custom/tree_c.glb", 1.1, 1.5], ["custom/hill_a.glb", 4.5, 6.0]],
	WorldLayout.Zone.BERRY_HOLLOW: [["custom/tree_a.glb", 1.1, 1.5], ["custom/tree_b.glb", 1.1, 1.5],
		["custom/tree_c.glb", 1.1, 1.5], ["custom/hill_b.glb", 4.5, 6.0]],
}


func _build_border() -> void:
	var backdrop: Array = [
		["custom/mountain_a.glb", 7.0, 9.0],
		["custom/mountain_b.glb", 7.0, 9.0],
		["custom/hill_c.glb", 6.0, 8.0],
	]
	# Inner wall: individual trees just past the play boundary, with a
	# gap where each mob lane comes in.
	for i in range(90):
		var angle: float = _rng.randf() * TAU
		var p: Vector2 = _square_ring(angle, _rng.randf_range(border_inner - 1.5, border_inner + 3.0))
		if _lane_gap(p, 3.6):
			continue
		_place_from(WALL_NEAR[WorldLayout.corner_zone(p)], p)
	# Middle ring: denser woods behind.
	for i in range(70):
		var angle: float = _rng.randf() * TAU
		var p: Vector2 = _square_ring(angle, _rng.randf_range(border_inner + 3.0, border_outer - 6.0))
		if _lane_gap(p, 2.4):
			continue
		_place_from(WALL_FAR[WorldLayout.corner_zone(p)], p)
	# Backdrop: hills and mountains to close the horizon.
	for i in range(26):
		var angle: float = TAU * float(i) / 26.0 + _rng.randf_range(-0.08, 0.08)
		_place_from(backdrop, _square_ring(angle, _rng.randf_range(border_outer - 4.0, border_outer + 4.0)))


## A point on a rounded square ring, so the border follows the square
## play area.
func _square_ring(angle: float, radius: float) -> Vector2:
	var dir: Vector2 = Vector2(cos(angle), sin(angle))
	var squareness: float = maxf(absf(dir.x), absf(dir.y))
	return dir / squareness * radius * 0.92


## True near a lane axis: the forest opens there for the mob trails.
func _lane_gap(p: Vector2, half_width: float) -> bool:
	return absf(p.x) < half_width or absf(p.y) < half_width


func _place_from(models: Array, p: Vector2) -> Node3D:
	var pick: Array = models[_rng.randi() % models.size()]
	return _spawn_model(pick[0], Vector3(p.x, 0.0, p.y), _rng.randf_range(pick[1], pick[2]), _rng.randf() * TAU)


# --- Haunted lane mouths near the mob spawns -------------------------------

## Where each lane leaves the forest: a ragged gate of dead trees either
## side of the trail, and a glowing jack-o'-lantern by it.
func _build_haunted_edges() -> void:
	var dead: Array = ["custom/dead_tree_a.glb", "custom/dead_tree_b.glb", "custom/dead_tree_c.glb"]
	for spawn_angle in spawn_angles:
		var base: float = deg_to_rad(spawn_angle)
		var dir: Vector3 = Vector3(sin(base), 0, -cos(base))
		var side: Vector3 = Vector3(-dir.z, 0, dir.x)
		for i in range(6):
			var along: float = _rng.randf_range(17.0, 24.0)
			var offset: float = _rng.randf_range(2.4, 4.6) * (1.0 if i % 2 == 0 else -1.0)
			var pos: Vector3 = dir * along + side * offset
			_spawn_model(dead[_rng.randi() % dead.size()], pos, _rng.randf_range(0.9, 1.3), _rng.randf() * TAU)
		var lantern_pos: Vector3 = dir * 17.5 + side * _rng.randf_range(2.2, 2.8)
		var pumpkin: Node3D = _spawn_model("custom/jack_o_lantern.glb", lantern_pos, 0.85, _rng.randf() * TAU)
		if pumpkin != null:
			var glow: OmniLight3D = OmniLight3D.new()
			glow.light_color = Color(1.0, 0.5, 0.15)
			glow.light_energy = 1.2
			glow.omni_range = 3.5
			glow.position = Vector3(0, 0.6, 0)
			pumpkin.add_child(glow)
		_spawn_model("custom/pumpkin_small.glb", lantern_pos + side * 0.9 + dir * 0.4, 1.0, _rng.randf() * TAU)


# --- Camp ------------------------------------------------------------------

func _build_camp() -> void:
	var tent: Node3D = _spawn_model("custom/tent.glb", Vector3(-3.4, 0, -2.7), 1.25, deg_to_rad(125.0))
	_add_blocker(tent, Vector3(2.8, 2.0, 2.4))
	var logs: Node3D = _spawn_model("custom/woodpile.glb", Vector3(3.0, 0, -2.5), 1.0, deg_to_rad(-25.0))
	_add_blocker(logs, Vector3(1.3, 0.8, 0.8))
	_spawn_model("custom/crate.glb", Vector3(-5.3, 0, -0.8), 0.9, 0.4)
	_spawn_model("custom/crate.glb", Vector3(-4.7, 0, 0.1), 0.65, 1.1)
	_spawn_model("custom/barrel.glb", Vector3(-5.8, 0, 0.5), 0.9, 0.0)
	_spawn_model("custom/water_bucket.glb", Vector3(1.6, 0, -3.6), 1.2, 0.0)
	_build_homestead(tent)
	for pos in [Vector3(-2.1, 0, 2.9), Vector3(3.1, 0, 1.2)]:
		var lantern: Node3D = _spawn_model("custom/camp_lantern.glb", pos, 1.0, _rng.randf() * TAU)
		if lantern != null:
			var light: OmniLight3D = OmniLight3D.new()
			light.light_color = Color(1.0, 0.75, 0.4)
			light.light_energy = 0.9
			light.omni_range = 4.0
			light.position = Vector3(0, 0.75, 0)
			lantern.add_child(light)


## Feature 031: the cozy decor of concept 01/02. Feature 032: lantern
## posts mark where the footpaths and the road leave the yard; flower
## bushes ring the yard between them. Warm lights in the lantern posts
## and inside the tent make the night pools of light of concept 03.
func _build_homestead(tent: Node3D) -> void:
	_spawn_model("custom/log_seat.glb", Vector3(-1.95, 0, 0.7), 1.0, deg_to_rad(75.0))
	_spawn_model("custom/stump_seat.glb", Vector3(1.75, 0, 1.25), 0.95, 0.4)
	_spawn_model("custom/stump_seat.glb", Vector3(0.35, 0, 2.15), 0.8, 1.9)
	_spawn_model("custom/cook_tripod.glb", Vector3(1.7, 0, -1.7), 1.0, 0.3)
	# The signpost stands where the road and the woodlot path part.
	_spawn_model("custom/camp_sign.glb", Vector3(-2.5, 0, 5.4), 1.0, deg_to_rad(20.0))
	for spot in [Vector3(3.2, 0, 5.7), Vector3(-3.0, 0, -7.0), Vector3(-0.9, 0, 6.6), Vector3(7.0, 0, -2.6)]:
		var lamp: Node3D = _spawn_model("custom/lantern_post.glb", spot, 1.0, _rng.randf_range(-0.6, 0.6) + PI)
		if lamp != null:
			lamp.add_child(_warm_light(Vector3(0.44, 1.36, 0.0), 1.6, 5.5))
	var stall: Node3D = _spawn_model("custom/market_stall.glb", Vector3(3.9, 0, -5.7), 1.0, deg_to_rad(-15.0))
	_add_blocker(stall, Vector3(2.0, 1.0, 1.1))
	var well: Node3D = _spawn_model("custom/stone_well.glb", Vector3(6.8, 0, 3.7), 1.0, deg_to_rad(10.0))
	_add_blocker(well, Vector3(1.6, 1.0, 1.6))
	for i in range(14):
		var angle: float = TAU * (float(i) + _rng.randf_range(-0.3, 0.3)) / 14.0
		var p: Vector2 = Vector2(cos(angle), sin(angle)) * _rng.randf_range(6.3, 7.4)
		if _clear(p, 0.9):
			_spawn_model("custom/flower_bush.glb", Vector3(p.x, 0, p.y), _rng.randf_range(0.55, 0.8), _rng.randf() * TAU)
	if tent != null:
		tent.add_child(_warm_light(Vector3(-0.55, 0.5, 0.0), 0.8, 2.6))


# --- Groves (feature 032) ----------------------------------------------------

func _build_groves() -> void:
	_build_pine_grove()
	_build_pond()
	_build_woodlot()
	_build_berry_hollow()
	_build_ferns()
	# Small stones along the road's verges.
	for i in range(10):
		var z: float = _rng.randf_range(7.0, 19.0)
		var x: float = _rng.randf_range(1.4, 2.4) * (1.0 if i % 2 == 0 else -1.0)
		var p: Vector2 = Vector2(x, z)
		if _clear(p, 0.3, false):
			_spawn_model(BOULDERS[_rng.randi() % 3], Vector3(p.x, 0, p.y), _rng.randf_range(0.22, 0.35), _rng.randf() * TAU)


## NW: a stand of tall green pines round one giant old pine, a fallen
## log and toadstools in the needle litter.
func _build_pine_grove() -> void:
	_landmark("custom/pine_d.glb", Vector2(-15.0, -14.2), 1.8, 1.0)
	_spawn_model("custom/log_seat.glb", Vector3(-12.8, 0, -6.6), 1.35, 0.5)
	_scatter_grove(0, GREEN_PINES, 9, 13.5, 0.85, 1.25, 1.4, true)
	_scatter_grove(0, ["custom/toadstools.glb"], 4, 9.0, 0.7, 1.1, 0.8)


## NE: the pond, ringed with stones and reeds, lily pads on the water,
## clay banks (the resource nodes) and boulders and pines behind.
func _build_pond() -> void:
	var centre: Vector2 = WorldLayout.POND_CENTRE
	var water: MeshInstance3D = MeshInstance3D.new()
	water.name = "Pond"
	water.mesh = _make_pond_mesh(WorldLayout.POND_RADIUS + 0.25)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = WATER_SHADER
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = Vector3(centre.x, 0.03, centre.y)
	add_child(water)
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = WorldLayout.POND_RADIUS - 0.2
	cylinder.height = 1.0
	shape.shape = cylinder
	shape.position = Vector3(0, 0.5, 0)
	body.add_child(shape)
	add_child(body)
	body.position = Vector3(centre.x, 0, centre.y)
	# Stones round the rim, leaving the shore open where the path arrives.
	var approach: float = (Vector2(9.0, -9.0) - centre).angle()
	var reeds: Array = [[], []]
	for i in range(26):
		var a: float = TAU * float(i) / 26.0 + _rng.randf_range(-0.08, 0.08)
		if absf(angle_difference(a, approach)) < 0.6:
			continue
		var rim: Vector2 = centre + Vector2.from_angle(a) * (WorldLayout.POND_RADIUS + _rng.randf_range(0.0, 0.35))
		if i % 2 == 0:
			_spawn_model(BOULDERS[_rng.randi() % 3], Vector3(rim.x, 0, rim.y), _rng.randf_range(0.3, 0.55), _rng.randf() * TAU)
		elif absf(angle_difference(a, approach + PI)) < 2.0:
			# Reed beds on the far shore.
			for k in range(3):
				var q: Vector2 = rim + Vector2(_rng.randfn(0.0, 0.3), _rng.randfn(0.0, 0.3))
				var s: float = _rng.randf_range(0.8, 1.2)
				reeds[0].append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(q.x, 0, q.y)))
				reeds[1].append(Color(0.5, 0.6, 0.26).lerp(Color(0.7, 0.68, 0.34), _rng.randf()))
	_add_flower_multimesh("Reeds", _make_reed_mesh(), reeds, 0.5, 0.1)
	# Lily pads.
	var pads: Array = [[], []]
	for i in range(9):
		var q2: Vector2 = centre + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.8, WorldLayout.POND_RADIUS - 0.5)
		var s2: float = _rng.randf_range(0.7, 1.2)
		pads[0].append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s2, 1, s2)), Vector3(q2.x, 0.04, q2.y)))
		pads[1].append(Color(0.36, 0.56, 0.22).lerp(Color(0.5, 0.66, 0.26), _rng.randf()))
	_add_flower_multimesh("LilyPads", _make_lily_mesh(), pads, 0.005, 0.015)
	_scatter_grove(1, BOULDERS, 6, 14.5, 0.9, 1.6, 1.4)
	_scatter_grove(1, GREEN_PINES, 4, 15.5, 0.85, 1.15, 1.4, true)


## SW: the woodcutters' glade: cut stumps among the standing trees, a
## stacked woodpile, a chopping stump and a felled trunk, with taller
## woods behind.
func _build_woodlot() -> void:
	var pile: Node3D = _spawn_model("custom/woodpile.glb", Vector3(-12.4, 0, 6.4), 1.1, deg_to_rad(70.0))
	_add_blocker(pile, Vector3(1.4, 0.8, 0.9))
	_spawn_model("custom/stump_seat.glb", Vector3(-10.4, 0, 5.2), 1.0, 0.8)
	_spawn_model("custom/log_seat.glb", Vector3(-9.0, 0, 13.4), 1.5, deg_to_rad(-30.0))
	_scatter_grove(2, ["custom/tree_stump.glb"], 6, 7.5, 0.85, 1.15, 0.9)
	_scatter_grove(2, BROADLEAF, 5, 14.5, 0.9, 1.2, 1.6, true)


## SE: the lush hollow round a giant old stump with a fairy ring of
## toadstools (the mushroom patches grow beside it) and flowering bushes.
## The landmark is low on purpose: the sun casts shadows north, and
## anything tall here would darken the east lane and hide the kids.
func _build_berry_hollow() -> void:
	var stump: Vector2 = Vector2(12.8, 12.2)
	_landmark("custom/tree_stump.glb", stump, 2.6, 1.3)
	for i in range(10):
		var a: float = TAU * float(i) / 10.0 + _rng.randf_range(-0.15, 0.15)
		var q: Vector2 = stump + Vector2.from_angle(a) * _rng.randf_range(1.9, 2.3)
		if _clear(q, 0.3, false):
			_spawn_model("custom/toadstools.glb", Vector3(q.x, 0, q.y), _rng.randf_range(0.55, 0.8), _rng.randf() * TAU)
	_scatter_grove(3, ["custom/flower_bush.glb"], 6, 8.0, 0.7, 1.05, 1.0)
	_scatter_grove(3, BROADLEAF, 4, 14.5, 0.9, 1.2, 1.6, true)


## A large landmark model; reserves its footprint so nothing else
## crowds it.
func _landmark(path: String, p: Vector2, scale: float, footprint: float) -> Node3D:
	_keep_out.append([p, footprint])
	return _spawn_model(path, Vector3(p.x, 0, p.y), scale, _rng.randf() * TAU)


## Places `count` random models from `paths` inside grove `index`, at
## least `min_r` from the camp centre, off paths, lanes and each other.
## The camera looks north, so `tall` models in the southern groves keep
## to the back (south of z = TALL_SOUTH_LIMIT) where they cannot hide
## the kids.
func _scatter_grove(index: int, paths: Array, count: int, min_r: float, min_s: float, max_s: float, spacing: float,
		tall: bool = false) -> void:
	var grove: Array = WorldLayout.GROVES[index]
	var placed: int = 0
	var tries: int = 0
	while placed < count and tries < count * 30:
		tries += 1
		var p: Vector2 = grove[1] + Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf()) * (float(grove[2]) + 3.0)
		if p.length() < min_r or maxf(absf(p.x), absf(p.y)) > border_inner or not _clear(p, spacing):
			continue
		if tall and p.y > 0.0 and p.y < TALL_SOUTH_LIMIT:
			continue
		_keep_out.append([p, spacing * 0.5])
		var path: String = paths[_rng.randi() % paths.size()]
		_spawn_model(path, Vector3(p.x, 0, p.y), _rng.randf_range(min_s, max_s), _rng.randf() * TAU)
		placed += 1


# --- Ferns and water plants ------------------------------------------------

## Ferns carpet the shade of the Pine Grove and the back of the Woodlot,
## with a few under the great oak.
func _build_ferns() -> void:
	var data: Array = [[], []]
	for spec in [[0, 70], [2, 40], [3, 14]]:
		var grove: Array = WorldLayout.GROVES[spec[0]]
		var made: int = 0
		var tries: int = 0
		while made < spec[1] and tries < spec[1] * 10:
			tries += 1
			var p: Vector2 = grove[1] + Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf()) * (float(grove[2]) + 2.0)
			if p.length() < 9.0 or not _clear(p, 0.4, false) or WorldLayout.in_lane(p, -1.5):
				continue
			var s: float = _rng.randf_range(1.1, 1.7)
			data[0].append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, 0, p.y)))
			data[1].append(Color(0.38, 0.6, 0.2).lerp(Color(0.55, 0.72, 0.26), _rng.randf()))
			made += 1
	_add_flower_multimesh("Ferns", _make_fern_mesh(), data, 0.5, 0.06)


## Seven arching fronds, each a tapering rachis with paired leaflets;
## darker at the heart (about 0.5 m tall, 1 m across).
func _make_fern_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(7):
		var angle: float = TAU * float(i) / 7.0 + rng.randf_range(-0.2, 0.2)
		var out: Vector3 = Vector3(cos(angle), 0, sin(angle))
		var across: Vector3 = Vector3(-out.z, 0, out.x)
		var length: float = rng.randf_range(0.42, 0.55)
		var lift: float = rng.randf_range(0.42, 0.55)
		var steps: int = 6
		for k in range(steps):
			var t0: float = float(k) / steps
			var t1: float = float(k + 1) / steps
			var p0: Vector3 = out * length * t0 + Vector3(0, lift * sin(t0 * PI * 0.8), 0)
			var p1: Vector3 = out * length * t1 + Vector3(0, lift * sin(t1 * PI * 0.8), 0)
			var w: float = 0.11 * (1.0 - t0 * 0.85)
			var shade: Color = Color.WHITE.darkened(0.45 * (1.0 - t0))
			# A pair of leaflets: from the rachis out and forward.
			for side in [1.0, -1.0]:
				var tip: Vector3 = p0.lerp(p1, 0.7) + across * w * side + Vector3(0, -0.02, 0)
				for v in [p0, p1, tip]:
					st.set_color(shade)
					st.set_normal(Vector3.UP)
					st.add_vertex(v)
	return st.commit()


## A clump of tall reed blades and two cattail heads (about 0.9 m).
func _make_reed_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	for i in range(7):
		var angle: float = rng.randf() * TAU
		var out: Vector3 = Vector3(cos(angle), 0, sin(angle))
		var across: Vector3 = Vector3(-out.z, 0, out.x)
		var height: float = rng.randf_range(0.6, 0.95)
		var base: Vector3 = out * rng.randf_range(0.0, 0.08)
		var tip: Vector3 = base + out * rng.randf_range(0.08, 0.2) + Vector3(0, height, 0)
		for v in [base - across * 0.025, base + across * 0.025, tip]:
			st.set_color(Color.WHITE)
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var head_colour: Color = Color(0.45, 0.3, 0.18)
	for spot in [Vector3(0.04, 0.0, 0.02), Vector3(-0.05, 0.0, -0.03)]:
		var h: float = 0.85 if spot.x > 0.0 else 0.72
		_add_stem(st, spot, spot + Vector3(0, h, 0), 0.01)
		for side in [Vector3(0.03, 0, 0), Vector3(0, 0, 0.03)]:
			var a: Vector3 = spot + Vector3(0, h - 0.2, 0)
			var b: Vector3 = spot + Vector3(0, h - 0.04, 0)
			for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
				st.set_color(head_colour)
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	return st.commit()


## A round lily pad with a notch (about 0.4 m across), lying flat.
func _make_lily_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int = 10
	for k in range(segments - 1):
		var a0: float = 0.35 + (TAU - 0.7) * float(k) / (segments - 1)
		var a1: float = 0.35 + (TAU - 0.7) * float(k + 1) / (segments - 1)
		for v in [Vector3(0, 0.01, 0), Vector3(cos(a1) * 0.2, 0.01, sin(a1) * 0.2), Vector3(cos(a0) * 0.2, 0.01, sin(a0) * 0.2)]:
			st.set_color(Color.WHITE)
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()


## A flat disc with a softly wobbling shoreline. UV.x carries the
## distance from the centre (0) to the shore (1) for the water shader.
func _make_pond_mesh(radius: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int = 40
	var rim: Array = []
	for k in range(segments):
		var a: float = TAU * float(k) / segments
		var wobble: float = 1.0 + 0.07 * sin(a * 3.0 + 0.6) + 0.04 * sin(a * 7.0 + 1.3)
		rim.append(Vector3(cos(a), 0, sin(a)) * radius * wobble)
	for k in range(segments):
		var r0: Vector3 = rim[k]
		var r1: Vector3 = rim[(k + 1) % segments]
		for ring in range(2):
			# Two rings: an inner disc and an outer band, so the shore
			# gradient interpolates smoothly.
			var f0: float = 0.6 if ring == 1 else 0.0
			var f1: float = 1.0 if ring == 1 else 0.6
			var quad: Array = [[r0 * f0, f0], [r1 * f0, f0], [r1 * f1, f1], [r0 * f1, f1]]
			var tris: Array = [quad[0], quad[2], quad[1], quad[0], quad[3], quad[2]] if ring == 1 else [quad[0], quad[3], quad[2]]
			for v in tris:
				st.set_uv(Vector2(v[1], 0.0))
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
	return st.commit()


func _warm_light(at: Vector3, energy: float, reach: float) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.38)
	light.light_energy = energy
	light.omni_range = reach
	light.position = at
	return light


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


## True when solid decor may go at `p`: off resource nodes and reserved
## spots, footpaths and the pond, and (with `keep_lanes_open`) out of the
## mob lanes.
func _clear(p: Vector2, margin: float, keep_lanes_open: bool = true) -> bool:
	if _blocked(p, margin) or on_path(p, margin * 0.5 + 0.2) or WorldLayout.in_pond(p, margin * 0.5 + 0.3):
		return false
	return not (keep_lanes_open and WorldLayout.in_lane(p, margin * 0.5))


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
	if path.contains("hill") or path.contains("mountain"):
		node.set_meta(Stylize.TINT_META, Stylize.TINT_FOLIAGE)
	elif path.contains("rock"):
		node.set_meta(Stylize.TINT_META, Stylize.TINT_ROCK)
	if (path.contains("tree_") or path.contains("pine_") or path.contains("bush")) and not path.contains("dead"):
		node.set_meta(Stylize.FOLIAGE_META, true)
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
	_keep_out.append([Vector2(owner_node.position.x, owner_node.position.z), maxf(size.x, size.z) * 0.5])
