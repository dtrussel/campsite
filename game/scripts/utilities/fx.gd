class_name Fx
extends RefCounted

## Fx
##
## Tiny, asset-free feedback helpers shared by every damageable thing:
## a hit flash, floating numbers, and an overhead HP label. All of it
## is placeholder "juice" built from engine primitives so the
## prototype reads clearly without art or audio.

const FLASH_SECONDS: float = 0.12
const FLOAT_SECONDS: float = 0.9
const FLOAT_RISE: float = 1.2

static var _flash_materials: Dictionary = {}  # Color -> StandardMaterial3D
static var _fonts: Dictionary = {}  # key -> Font

const BODY_FONT_PATH: String = "res://assets/fonts/NunitoSans.ttf"
const TITLE_FONT_PATH: String = "res://assets/fonts/Cinzel.ttf"


## Nunito Sans at a given weight (variable font).
static func body_font(weight: int = 600) -> Font:
	return _variable_font(BODY_FONT_PATH, weight)


static func bold_font() -> Font:
	return _variable_font(BODY_FONT_PATH, 850)


## Cinzel, the LoL-like display serif used for titles.
static func title_font(weight: int = 700) -> Font:
	return _variable_font(TITLE_FONT_PATH, weight)


static func _variable_font(path: String, weight: int) -> Font:
	var key: String = "%s@%d" % [path, weight]
	if not _fonts.has(key):
		var base: FontFile = load(path) as FontFile
		if base == null:
			return ThemeDB.fallback_font
		var variation: FontVariation = FontVariation.new()
		variation.base_font = base
		var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
		variation.variation_opentype = { tag: weight }
		_fonts[key] = variation
	return _fonts[key]


## Briefly tints every mesh under `node` with a bright overlay.
static func flash(node: Node, color: Color = Color(1, 0.35, 0.3, 0.75)) -> void:
	if node == null or not node.is_inside_tree():
		return
	var material: StandardMaterial3D = _get_flash_material(color)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(node, meshes)
	for mesh in meshes:
		mesh.material_overlay = material
	var tween: Tween = node.create_tween()
	tween.tween_interval(FLASH_SECONDS)
	tween.tween_callback(func() -> void:
		for mesh in meshes:
			if is_instance_valid(mesh):
				mesh.material_overlay = null
	)


## Spawns a billboard label that pops, rises and fades, e.g. "-4" or
## "+5 XP" (LoL-style combat text).
static func float_text(anchor: Node3D, text: String, color: Color, height: float = 1.6) -> void:
	if anchor == null or not anchor.is_inside_tree():
		return
	var scene_root: Node = anchor.get_tree().current_scene
	if scene_root == null:
		return
	var label: Label3D = Label3D.new()
	label.text = text
	label.font = bold_font()
	label.modulate = color
	label.outline_modulate = Color(0.05, 0.03, 0.02, 1)
	label.outline_size = 14
	label.font_size = 56
	label.pixel_size = 0.009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 20
	label.outline_render_priority = 19
	scene_root.add_child(label)
	var jitter: Vector3 = Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.2, 0.2))
	label.global_position = anchor.global_position + Vector3(0, height, 0) + jitter
	label.scale = Vector3.ONE * 1.7
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + FLOAT_RISE, FLOAT_SECONDS) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_SECONDS * 0.5).set_delay(FLOAT_SECONDS * 0.5)
	tween.tween_property(label, "outline_modulate:a", 0.0, FLOAT_SECONDS * 0.5).set_delay(FLOAT_SECONDS * 0.5)
	tween.chain().tween_callback(label.queue_free)


## Creates an overhead HP label as a child of `owner_node`.
static func make_hp_label(owner_node: Node3D, height: float) -> Label3D:
	var label: Label3D = Label3D.new()
	label.name = "HPLabel"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 48
	label.pixel_size = 0.009
	label.outline_size = 12
	label.outline_modulate = Color(0, 0, 0, 1)
	label.position = Vector3(0, height, 0)
	owner_node.add_child(label)
	return label


## Renders current / max as a compact bar, e.g. "||||||....  30/50".
static func hp_bar_text(current: int, maximum: int, segments: int = 10) -> String:
	if maximum <= 0:
		return ""
	var filled: int = int(ceil(float(current) / float(maximum) * segments))
	filled = clampi(filled, 0, segments)
	return "%s%s %d/%d" % ["|".repeat(filled), ".".repeat(segments - filled), current, maximum]


static func hp_color(current: int, maximum: int) -> Color:
	var ratio: float = 0.0 if maximum <= 0 else float(current) / float(maximum)
	if ratio > 0.6:
		return Color(0.55, 1.0, 0.55)
	if ratio > 0.3:
		return Color(1.0, 0.85, 0.35)
	return Color(1.0, 0.4, 0.35)


static func _get_flash_material(color: Color) -> StandardMaterial3D:
	if not _flash_materials.has(color):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = color
		_flash_materials[color] = material
	return _flash_materials[color]


static func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			out.append(child)
		_collect_meshes(child, out)


# --- Particle bursts --------------------------------------------------------

## kind -> [amount, lifetime, color_start, color_end, speed, gravity_y,
##          size, additive, spread_degrees]
const BURSTS: Dictionary = {
	&"hit": [14, 0.35, Color(1, 0.98, 0.75), Color(1, 0.55, 0.15, 0), 5.0, -4.0, 0.16, true, 180.0],
	&"dust": [16, 0.8, Color(0.75, 0.62, 0.45, 0.8), Color(0.6, 0.5, 0.4, 0), 1.6, 0.4, 0.5, false, 90.0],
	&"wood": [14, 0.7, Color(0.72, 0.48, 0.25), Color(0.5, 0.32, 0.16, 0), 3.5, -9.0, 0.14, false, 60.0],
	&"stone": [14, 0.7, Color(0.8, 0.8, 0.85), Color(0.5, 0.5, 0.55, 0), 3.5, -9.0, 0.13, false, 60.0],
	&"leaves": [16, 1.1, Color(0.55, 0.85, 0.3), Color(0.9, 0.6, 0.2, 0), 2.5, -2.0, 0.16, false, 70.0],
	&"berries": [12, 0.8, Color(0.95, 0.25, 0.35), Color(0.6, 0.1, 0.2, 0), 2.8, -7.0, 0.13, false, 60.0],
	&"resin": [12, 0.8, Color(1.0, 0.75, 0.3), Color(0.9, 0.5, 0.1, 0), 2.5, -6.0, 0.13, true, 60.0],
	&"heal": [18, 1.0, Color(0.55, 1.0, 0.55), Color(0.3, 1.0, 0.6, 0), 1.0, 2.5, 0.16, true, 40.0],
	&"level_up": [48, 1.4, Color(1.0, 0.9, 0.45), Color(1.0, 0.7, 0.2, 0), 1.6, 3.5, 0.2, true, 25.0],
	&"shadow_death": [26, 1.0, Color(0.55, 0.2, 0.8, 0.9), Color(0.1, 0.0, 0.2, 0), 1.8, 1.5, 0.6, false, 70.0],
	&"shadow_spawn": [30, 1.3, Color(0.35, 0.1, 0.55, 0.9), Color(0.05, 0.0, 0.1, 0), 1.2, 2.0, 0.6, false, 25.0],
	&"build": [22, 0.9, Color(0.8, 0.68, 0.5, 0.85), Color(0.65, 0.55, 0.45, 0), 2.4, 0.3, 0.55, false, 85.0],
	&"sparkle": [10, 0.7, Color(1.0, 0.95, 0.7), Color(1.0, 0.8, 0.3, 0), 1.5, 1.0, 0.12, true, 60.0],
}

static var _soft_texture: Texture2D = null
static var _burst_materials: Dictionary = {}  # additive(bool) -> material


## One-shot particle burst at a world position. Safe to call from
## anywhere; does nothing outside the scene tree or for unknown kinds.
static func burst(kind: StringName, position: Vector3) -> void:
	if not BURSTS.has(kind):
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var spec: Array = BURSTS[kind]
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = spec[0]
	particles.lifetime = spec[1]
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, spec[2])
	ramp.set_color(1, spec[3])
	particles.color_ramp = ramp
	particles.direction = Vector3.UP
	particles.spread = spec[8]
	particles.initial_velocity_min = float(spec[4]) * 0.5
	particles.initial_velocity_max = float(spec[4])
	particles.gravity = Vector3(0, spec[5], 0)
	particles.damping_min = 1.0
	particles.damping_max = 2.0
	particles.scale_amount_min = float(spec[6]) * 0.6
	particles.scale_amount_max = float(spec[6])
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1, 0.2))
	particles.scale_amount_curve = curve
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _get_burst_material(spec[7])
	particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree.current_scene.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	tree.create_timer(float(spec[1]) + 0.5, false).timeout.connect(particles.queue_free)


## Soft round sprite shared by every particle effect.
static func soft_texture() -> Texture2D:
	if _soft_texture == null:
		var gradient: Gradient = Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.45, Color(1, 1, 1, 0.8))
		var texture: GradientTexture2D = GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		_soft_texture = texture
	return _soft_texture


## Billboard particle material: soft sprite tinted by the color ramp.
static func particle_material(additive: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Without this the particle scale is dropped and every sprite is 1 m wide.
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = soft_texture()
	material.disable_receive_shadows = true
	return material


static func _get_burst_material(additive: bool) -> StandardMaterial3D:
	if not _burst_materials.has(additive):
		_burst_materials[additive] = particle_material(additive)
	return _burst_materials[additive]


## Adds camera shake (0..1). The active camera rig decays it.
static func shake(amount: float) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var rig: Node = tree.get_first_node_in_group("camera_rig")
	if rig != null and rig.has_method("add_trauma"):
		rig.add_trauma(amount)
