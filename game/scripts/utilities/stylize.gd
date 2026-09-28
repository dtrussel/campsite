class_name Stylize
extends RefCounted

## Stylize
##
## House look for every imported model. KayKit models use one gradient
## atlas texture; we keep it and push the shading toward a painterly,
## readable, LoL-like finish: matte surfaces, a bright rim light that
## separates characters from the ground, and small saturation lifts.
##
## Profiles:
##   "hero"   - player / companion: strong warm rim.
##   "shadow" - night minions: darkened purple body, violet glow,
##              burning eyes.
##   "prop"   - world props: soft rim only.
## Styled materials are cached per (source material, profile) so
## instances keep sharing materials.

const EYE_MESH_HINT: String = "Eyes"
## Optional Color metadata on a mesh or any ancestor (up to a few
## levels) that multiplies the albedo, e.g. to warm up KayKit's teal
## trees or grey its white rocks.
const TINT_META: StringName = &"style_tint"

## Shared tints so the world stays colour-consistent.
const TINT_FOLIAGE: Color = Color(0.92, 0.78, 0.48)
const TINT_ROCK: Color = Color(0.62, 0.63, 0.7)

static var _cache: Dictionary = {}  # "<instance id>|<profile>" -> Material


static func apply(root: Node, profile: String = "prop") -> void:
	if root == null:
		return
	var meshes: Array[MeshInstance3D] = []
	_collect(root, meshes)
	for mesh in meshes:
		apply_mesh(mesh, profile)


static func apply_mesh(mesh: MeshInstance3D, profile: String) -> void:
	if mesh.mesh == null:
		return
	var is_eye: bool = profile == "shadow" and mesh.name.contains(EYE_MESH_HINT)
	var tint: Color = _find_tint(mesh)
	for surface in range(mesh.mesh.get_surface_count()):
		var source: Material = mesh.mesh.surface_get_material(surface)
		if mesh.get_surface_override_material(surface) != null and not mesh.has_meta(&"stylized"):
			source = mesh.get_surface_override_material(surface)
		var base: StandardMaterial3D = source as StandardMaterial3D
		if base == null:
			continue
		var key: String = "%d|%s|%s|%s" % [base.get_instance_id(), profile, is_eye, tint.to_html()]
		if not _cache.has(key):
			var made: StandardMaterial3D = _make(base, profile, is_eye)
			made.albedo_color *= tint
			_cache[key] = made
		mesh.set_surface_override_material(surface, _cache[key])
	mesh.set_meta(&"stylized", profile)


static func _find_tint(node: Node) -> Color:
	var current: Node = node
	for i in range(6):
		if current == null:
			break
		if current.has_meta(TINT_META):
			return current.get_meta(TINT_META)
		current = current.get_parent()
	return Color.WHITE


static func _make(base: StandardMaterial3D, profile: String, is_eye: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = base.duplicate() as StandardMaterial3D
	material.metallic = 0.0
	material.roughness = 1.0
	material.metallic_specular = 0.2
	material.rim_enabled = true
	match profile:
		"hero":
			material.rim = 0.55
			material.rim_tint = 0.25
		"shadow":
			if is_eye:
				material.albedo_color = Color(1.0, 0.45, 0.9)
				material.emission_enabled = true
				material.emission = Color(1.0, 0.25, 0.85)
				material.emission_energy_multiplier = 4.0
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			else:
				material.albedo_color = Color(0.2, 0.15, 0.3)
				material.emission_enabled = true
				material.emission = Color(0.3, 0.06, 0.5)
				material.emission_energy_multiplier = 0.35
				material.rim = 0.8
				material.rim_tint = 0.9
		_:
			material.rim = 0.25
			material.rim_tint = 0.5
	return material


static func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect(child, out)
