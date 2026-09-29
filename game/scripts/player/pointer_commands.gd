extends Node

## PointerCommands
##
## LoL-style mouse control for the boy:
##   Right click ground    -> move there (green click marker)
##   Right/left click imp  -> attack it (walk into range, auto-attack)
##   Right/left click node -> walk over and gather
##   Right/left click fire -> walk over and open crafting
##   Right/left click a damaged building -> walk over and repair it
##   Right/left click a Crafting Table -> walk over and open crafting
## Also drives the hover feedback: a pulsing rim on the unit under the
## cursor, a context cursor (move / attack / gather / use), and the
## attack-range ring while an attack is targeted.
## Build mode owns the mouse while active (LMB place, RMB cancel).

const RIM_SHADER: Shader = preload("res://shaders/hover_rim.gdshader")
const PICK_MASK: int = 1 | 2 | 4 | 8
const MOB_PICK_RADIUS: float = 1.0
const NODE_PICK_RADIUS: float = 0.9

enum Hover { NONE, GROUND, MOB, RESOURCE, CAMPFIRE, REPAIR }

var _player: Node3D = null
var _hover_kind: int = Hover.NONE
var _hover_target: Node3D = null
var _hover_point: Vector3 = Vector3.ZERO
var _highlighted: Array[MeshInstance3D] = []
var _rim_materials: Dictionary = {}  # Hover -> ShaderMaterial
var _range_ring: MeshInstance3D = null
var _cursors: Dictionary = {}  # Hover -> Texture2D


func _ready() -> void:
	for kind in [Hover.MOB, Hover.RESOURCE, Hover.CAMPFIRE, Hover.REPAIR]:
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = RIM_SHADER
		material.set_shader_parameter("rim_color", _hover_color(kind))
		_rim_materials[kind] = material
	_build_cursors()
	_apply_cursor(Hover.GROUND)
	tree_exiting.connect(func() -> void: Input.set_custom_mouse_cursor(null))


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player != null and _range_ring == null:
			_range_ring = _make_range_ring()
		return
	if get_tree().paused or not GameManager.is_playing() or BuildManager.is_in_build_mode():
		_set_hover(Hover.NONE, null)
		_apply_cursor(Hover.GROUND)
		_update_range_ring()
		return
	_pick_under_mouse()
	_update_range_ring()


func _unhandled_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index != MOUSE_BUTTON_RIGHT and button.button_index != MOUSE_BUTTON_LEFT:
		return
	if _player == null or get_tree().paused or not GameManager.is_playing():
		return
	if BuildManager.is_in_build_mode():
		return  # BuildManager handles place / cancel
	_pick_under_mouse()
	var is_right: bool = button.button_index == MOUSE_BUTTON_RIGHT
	match _hover_kind:
		Hover.MOB:
			_player.command_attack(_hover_target)
			_spawn_marker(_hover_target.global_position, Color(1.0, 0.3, 0.25))
		Hover.RESOURCE:
			_player.command_gather(_hover_target)
			_spawn_marker(_hover_target.global_position, Color(1.0, 0.85, 0.35))
		Hover.REPAIR:
			_player.command_repair(_hover_target)
			_spawn_marker(_hover_target.global_position, Color(0.45, 1.0, 0.5))
		Hover.CAMPFIRE:
			_player.command_campfire(_hover_target)
			_spawn_marker(_hover_target.global_position, Color(0.3, 0.95, 0.9))
		Hover.GROUND:
			if not is_right:
				return  # left click on plain ground does nothing (LoL)
			_player.command_move(_hover_point)
			_spawn_marker(_hover_point, Color(0.45, 1.0, 0.5))
		_:
			return
	get_viewport().set_input_as_handled()


# --- Picking -----------------------------------------------------------------

func _pick_under_mouse() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		_set_hover(Hover.NONE, null)
		return
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(mouse)
	var direction: Vector3 = camera.project_ray_normal(mouse)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + direction * 300.0, PICK_MASK
	)
	var space: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	# Ground point under the cursor (plane y=0) for proximity picking.
	var ground: Vector3 = origin
	if absf(direction.y) > 0.001:
		ground = origin + direction * (-origin.y / direction.y)
	_hover_point = ground

	var collider: Node = hit.get("collider") as Node
	if collider != null:
		if collider.is_in_group("mobs"):
			_set_hover(Hover.MOB, collider as Node3D)
			return
		if collider is ResourceNode and (collider as ResourceNode).is_gatherable:
			_set_hover(Hover.RESOURCE, collider as Node3D)
			return
		if collider.is_in_group("base_core"):
			_set_hover(Hover.CAMPFIRE, collider as Node3D)
			return
		if collider is Building and Repair.needs_repair(collider):
			_set_hover(Hover.REPAIR, collider as Node3D)
			return
		if collider is CraftingTable:
			# A second crafting station: same "walk over and craft" as the fire.
			_set_hover(Hover.CAMPFIRE, collider as Node3D)
			return
	# Forgiving picks: small units near the cursor's ground point.
	var mob: Node3D = _nearest_in_group("mobs", ground, MOB_PICK_RADIUS)
	if mob != null:
		_set_hover(Hover.MOB, mob)
		return
	var base: Node3D = get_tree().get_first_node_in_group("base_core") as Node3D
	if base != null and _flat(base.global_position, ground) < 1.1:
		_set_hover(Hover.CAMPFIRE, base)
		return
	_set_hover(Hover.GROUND, null)


func _nearest_in_group(group: StringName, point: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d: float = radius
	for node in get_tree().get_nodes_in_group(group):
		var n3d: Node3D = node as Node3D
		if n3d == null:
			continue
		var d: float = _flat(n3d.global_position, point)
		if d < best_d:
			best_d = d
			best = n3d
	return best


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Hover feedback --------------------------------------------------------

func _set_hover(kind: int, target: Node3D) -> void:
	if kind == _hover_kind and target == _hover_target:
		# Re-apply if a hit flash cleared the overlay.
		if not _highlighted.is_empty() and is_instance_valid(_highlighted[0]) \
				and _highlighted[0].material_overlay == null:
			_highlight(kind, target)
		return
	_clear_highlight()
	_hover_kind = kind
	_hover_target = target
	if target != null:
		_highlight(kind, target)
	_apply_cursor(kind)


func _highlight(kind: int, target: Node3D) -> void:
	_highlighted.clear()
	_collect_meshes(target, _highlighted)
	var material: ShaderMaterial = _rim_materials.get(kind)
	for mesh in _highlighted:
		mesh.material_overlay = material


func _clear_highlight() -> void:
	for mesh in _highlighted:
		if is_instance_valid(mesh):
			mesh.material_overlay = null
	_highlighted.clear()


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is HealthBar3D:
			continue
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			out.append(child)
		if child is Node3D and not (child as Node3D).visible:
			continue
		_collect_meshes(child, out)


func _hover_color(kind: int) -> Color:
	match kind:
		Hover.MOB:
			return Color(1.0, 0.25, 0.2)
		Hover.RESOURCE:
			return Color(1.0, 0.82, 0.3)
		Hover.CAMPFIRE:
			return Color(0.25, 0.95, 0.9)
		Hover.REPAIR:
			return Color(0.45, 1.0, 0.5)
	return Color.WHITE


# --- Range ring and click markers -------------------------------------------

func _make_range_ring() -> MeshInstance3D:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	var reach: float = float(_player.get("attack_range"))
	torus.inner_radius = reach - 0.05
	torus.outer_radius = reach + 0.02
	torus.rings = 48
	ring.mesh = torus
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.45, 0.35, 0.55)
	material.no_depth_test = true
	ring.material_override = material
	ring.scale = Vector3(1, 0.05, 1)
	ring.position = Vector3(0, 0.05, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.set_meta(&"stylized", "skip")
	ring.visible = false
	_player.add_child(ring)
	return ring


func _update_range_ring() -> void:
	if _range_ring == null or _player == null:
		return
	var attacking: bool = int(_player.get("command")) == 2  # Command.ATTACK
	_range_ring.visible = (attacking or _hover_kind == Hover.MOB) and not bool(_player.get("is_knocked_out"))


func _spawn_marker(position: Vector3, color: Color) -> void:
	var scene_root: Node = get_tree().current_scene
	var marker: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.55
	torus.rings = 32
	marker.mesh = torus
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color
	material.no_depth_test = true
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.set_meta(&"stylized", "skip")
	scene_root.add_child(marker)
	marker.global_position = Vector3(position.x, 0.06, position.z)
	marker.scale = Vector3(1.4, 0.05, 1.4)
	var tween: Tween = marker.create_tween()
	tween.set_parallel(true)
	tween.tween_property(marker, "scale", Vector3(0.3, 0.05, 0.3), 0.35).set_ease(Tween.EASE_IN)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(marker.queue_free)


# --- Cursors -----------------------------------------------------------------

func _apply_cursor(kind: int) -> void:
	var texture: Texture2D = _cursors.get(kind, _cursors.get(Hover.GROUND))
	if texture != null and DisplayServer.get_name() != "headless":
		Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, Vector2(2, 2))


## Draws small arrow cursors in the hover colours (gold for move).
func _build_cursors() -> void:
	var fills: Dictionary = {
		Hover.GROUND: Color(0.95, 0.8, 0.45),
		Hover.MOB: Color(1.0, 0.3, 0.25),
		Hover.RESOURCE: Color(1.0, 0.9, 0.4),
		Hover.CAMPFIRE: Color(0.3, 0.95, 0.9),
		Hover.REPAIR: Color(0.5, 1.0, 0.55),
	}
	var arrow: PackedVector2Array = PackedVector2Array([
		Vector2(2, 2), Vector2(2, 24), Vector2(8, 18), Vector2(12, 28),
		Vector2(16, 26), Vector2(12, 17), Vector2(20, 17),
	])
	for kind in fills.keys():
		var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in range(32):
			for x in range(32):
				var p: Vector2 = Vector2(x + 0.5, y + 0.5)
				if Geometry2D.is_point_in_polygon(p, arrow):
					var edge: bool = false
					for offset in [Vector2(1.5, 0), Vector2(-1.5, 0), Vector2(0, 1.5), Vector2(0, -1.5)]:
						if not Geometry2D.is_point_in_polygon(p + offset, arrow):
							edge = true
					var fill: Color = fills[kind]
					var shade: float = 1.0 - float(y) / 60.0
					image.set_pixel(x, y, Color(0.08, 0.05, 0.02) if edge else Color(fill.r * shade, fill.g * shade, fill.b * shade))
		_cursors[kind] = ImageTexture.create_from_image(image)
