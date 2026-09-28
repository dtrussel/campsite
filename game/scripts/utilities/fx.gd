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


## Spawns a billboard label that rises and fades, e.g. "-4" or "+5 XP".
static func float_text(anchor: Node3D, text: String, color: Color, height: float = 1.6) -> void:
	if anchor == null or not anchor.is_inside_tree():
		return
	var scene_root: Node = anchor.get_tree().current_scene
	if scene_root == null:
		return
	var label: Label3D = Label3D.new()
	label.text = text
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, 1)
	label.outline_size = 10
	label.font_size = 48
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	scene_root.add_child(label)
	var jitter: Vector3 = Vector3(randf_range(-0.25, 0.25), 0.0, randf_range(-0.25, 0.25))
	label.global_position = anchor.global_position + Vector3(0, height, 0) + jitter
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + FLOAT_RISE, FLOAT_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_SECONDS).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


## Creates an overhead HP label as a child of `owner_node`.
static func make_hp_label(owner_node: Node3D, height: float) -> Label3D:
	var label: Label3D = Label3D.new()
	label.name = "HPLabel"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 40
	label.pixel_size = 0.005
	label.outline_size = 8
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
