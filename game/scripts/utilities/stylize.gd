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
const OUTLINE_SHADER: Shader = preload("res://shaders/outline.gdshader")
## Materials baked by the art pipeline (art/lib/paint_bake.py) end with
## this suffix: their lighting is painted into the texture, so they get
## a softer, wrap-lit, matte finish instead of the KayKit treatment.
const PAINTED_SUFFIX: String = "_painted"
## Optional Color metadata on a mesh or any ancestor (up to a few
## levels) that multiplies the albedo: KayKit and painted materials
## alike (not glowing ones nor swaying foliage). The badge cosmetics
## (Cosmetics: hero outfits, tent colours) tint through it.
const TINT_META: StringName = &"style_tint"
## Meta on a model (or any ancestor) whose painted meshes sway in the
## wind: trees, pines and bushes.
const FOLIAGE_META: StringName = &"foliage"
const FOLIAGE_SHADER: Shader = preload("res://shaders/painted_foliage.gdshader")
## Painted props, buildings and characters: wrap-lit,
## matte, soft rim, plus sunny tops, contact shade and texel detail.
const PAINTED_SHADER: Shader = preload("res://shaders/painted_prop.gdshader")
## Thin warm ink line on painted props (HD-2D target).
const PROP_OUTLINE_COLOR: Color = Color(0.2, 0.12, 0.07)
const PROP_OUTLINE_THICKNESS: float = 0.011

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
	var foliage: bool = profile == "prop" and _has_meta_up(mesh, FOLIAGE_META)
	var tint: Color = _find_tint(mesh)
	for surface in range(mesh.mesh.get_surface_count()):
		var source: Material = mesh.mesh.surface_get_material(surface)
		if mesh.get_surface_override_material(surface) != null and not mesh.has_meta(&"stylized"):
			source = mesh.get_surface_override_material(surface)
		var base: StandardMaterial3D = source as StandardMaterial3D
		if base == null:
			continue
		if foliage and base.resource_name.ends_with(PAINTED_SUFFIX) and not base.emission_enabled:
			var aabb: AABB = mesh.mesh.get_aabb()
			var foliage_key: String = "foliage|%d|%.2f|%.2f" % [base.get_instance_id(), aabb.position.y, aabb.size.y]
			if not _cache.has(foliage_key):
				_cache[foliage_key] = _make_foliage(base, aabb)
			mesh.set_surface_override_material(surface, _cache[foliage_key])
			continue
		var key: String = "%d|%s|%s|%s" % [base.get_instance_id(), profile, is_eye, tint.to_html()]
		if not _cache.has(key):
			var made: Material
			if base.resource_name.ends_with(PAINTED_SUFFIX) or base.emission_enabled:
				made = _make_painted(base, profile, tint)
			else:
				var kaykit: StandardMaterial3D = _make(base, profile, is_eye)
				kaykit.albedo_color *= tint
				made = kaykit
			_cache[key] = made
		mesh.set_surface_override_material(surface, _cache[key])
	mesh.set_meta(&"stylized", profile)


static func _has_meta_up(node: Node, meta: StringName) -> bool:
	var current: Node = node
	for i in range(6):
		if current == null:
			return false
		if current.has_meta(meta):
			return bool(current.get_meta(meta))
		current = current.get_parent()
	return false


## Painted foliage that sways in the wind (see painted_foliage.gdshader).
static func _make_foliage(base: StandardMaterial3D, aabb: AABB) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = FOLIAGE_SHADER
	material.set_shader_parameter("albedo_texture", base.albedo_texture)
	material.set_shader_parameter("albedo_color", base.albedo_color)
	material.set_shader_parameter("base_y", aabb.position.y)
	material.set_shader_parameter("height", maxf(aabb.size.y, 0.1))
	return material


static func _find_tint(node: Node) -> Color:
	var current: Node = node
	for i in range(6):
		if current == null:
			break
		if current.has_meta(TINT_META):
			return current.get_meta(TINT_META)
		current = current.get_parent()
	return Color.WHITE


## Painted (baked) assets: soft wrap lighting keeps the painted shading
## readable at night, plus the shared painted finish
## (painted_common.gdshaderinc). Everything gets a thin ink line: warm
## brown on props, darker on heroes, heavy purple on imps.
static func _make_painted(base: StandardMaterial3D, profile: String, tint: Color = Color.WHITE) -> Material:
	if base.emission_enabled:
		# Glowing bits (imp eyes, wand star, lantern glass): keep them bright at night.
		var glow: StandardMaterial3D = base.duplicate() as StandardMaterial3D
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = base.emission * 1.1
		return glow
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = PAINTED_SHADER
	material.set_shader_parameter("albedo_texture", base.albedo_texture)
	material.set_shader_parameter("albedo_color", base.albedo_color * tint)
	var character: bool = profile in ["hero", "shadow"]
	material.set_shader_parameter("rim_amount", 0.35 if character else 0.15)
	if character:
		# Characters move: lighter texel noise and no ground contact shade.
		material.set_shader_parameter("texel_amount", 0.02)
		material.set_shader_parameter("contact_dark", 0.0)
	var outline: ShaderMaterial = ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	match profile:
		"shadow":
			outline.set_shader_parameter("outline_color", Color(0.16, 0.03, 0.22))
			outline.set_shader_parameter("thickness", 0.022)
		"hero":
			# A thin warm dark-brown ink line (reads hand-drawn, not black-marker).
			outline.set_shader_parameter("outline_color", Color(0.16, 0.08, 0.05))
			outline.set_shader_parameter("thickness", 0.013)
		_:
			outline.set_shader_parameter("outline_color", PROP_OUTLINE_COLOR)
			outline.set_shader_parameter("thickness", PROP_OUTLINE_THICKNESS)
	material.next_pass = outline
	return material


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
