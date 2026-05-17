extends Node

## BuildManager
##
## Autoload that owns build-mode state and the active placement ghost.
## On enter_build_mode it instantiates the building's scene as a ghost,
## disables its physics, swaps its meshes to a translucent material, and
## attaches an Area3D footprint that drives overlap-based validity.
## On confirm_build it spends the resources via ResourceManager and
## spawns the real building. Stays in build mode after a placement so
## the player can drop several buildings in a row.

signal build_mode_entered(definition: BuildingDefinition)
signal build_mode_exited
signal building_placed(building: Node)
signal placement_validity_changed(is_valid: bool)

const BUILDINGS_DIR: String = "res://resources/buildings/"
const GHOST_NODE_NAME: StringName = &"_BuildGhost"
const FOOTPRINT_NODE_NAME: StringName = &"_GhostFootprint"
const GROUND_GROUP: StringName = &"ground"
const BUILD_XP_REWARD: int = 5

var _definitions: Array[BuildingDefinition] = []
var _by_id: Dictionary = {}                  # StringName -> BuildingDefinition

var _active_definition: BuildingDefinition = null
var _ghost: Node3D = null
var _ghost_meshes: Array[MeshInstance3D] = []
var _ghost_footprint: Area3D = null
var _is_valid: bool = false
var _has_ground_hit: bool = false

var _valid_material: StandardMaterial3D
var _invalid_material: StandardMaterial3D


func _ready() -> void:
	_valid_material = _make_ghost_material(Color(0.3, 1.0, 0.4, 0.55))
	_invalid_material = _make_ghost_material(Color(1.0, 0.3, 0.3, 0.55))
	_load_definitions()


func get_known_definitions() -> Array[BuildingDefinition]:
	return _definitions


func get_active_definition() -> BuildingDefinition:
	return _active_definition


func is_in_build_mode() -> bool:
	return _ghost != null


func enter_build_mode(definition: BuildingDefinition) -> bool:
	if definition == null or definition.scene == null:
		return false
	if is_in_build_mode():
		_destroy_ghost()
	_active_definition = definition
	if not _spawn_ghost(definition):
		_active_definition = null
		return false
	build_mode_entered.emit(definition)
	_update_validity(false, true)  # force initial emit
	return true


func exit_build_mode() -> void:
	if not is_in_build_mode() and _active_definition == null:
		return
	_destroy_ghost()
	_active_definition = null
	build_mode_exited.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_build_mode"):
		if is_in_build_mode():
			exit_build_mode()
		else:
			var first: BuildingDefinition = _definitions[0] if not _definitions.is_empty() else null
			if first != null:
				enter_build_mode(first)
		return

	if not is_in_build_mode():
		return

	if event.is_action_pressed("select_building_1"):
		_select_index(0)
	elif event.is_action_pressed("select_building_2"):
		_select_index(1)
	elif event.is_action_pressed("confirm_build"):
		_try_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel_build") or event.is_action_pressed("quit_game"):
		exit_build_mode()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not is_in_build_mode():
		return
	_update_ghost_transform()
	_update_validity(_compute_validity(), false)


func _select_index(idx: int) -> void:
	if idx < 0 or idx >= _definitions.size():
		return
	var next_def: BuildingDefinition = _definitions[idx]
	if next_def == _active_definition:
		return
	enter_build_mode(next_def)


func _try_confirm() -> void:
	if not _is_valid:
		return
	if _active_definition == null or _active_definition.scene == null:
		return
	if not ResourceManager.spend_costs(_active_definition.cost):
		return
	var building: Node = _active_definition.scene.instantiate()
	if _ghost != null:
		(building as Node3D).global_transform = _ghost.global_transform
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		building.queue_free()
		return
	scene_root.add_child(building)
	building_placed.emit(building)
	_award_build_xp()
	# Force a validity re-eval so the ghost flips to red if the cost can
	# no longer be afforded after spending.
	_update_validity(_compute_validity(), true)


func _award_build_xp() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	ProgressionManager.award_xp(players[0] as Node, BUILD_XP_REWARD, &"build")


func _spawn_ghost(definition: BuildingDefinition) -> bool:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return false
	var instance: Node = definition.scene.instantiate()
	var ghost: Node3D = instance as Node3D
	if ghost == null:
		instance.queue_free()
		return false
	ghost.name = GHOST_NODE_NAME

	# Disable physics on the root so the ghost neither blocks nor is hit.
	var sb: StaticBody3D = ghost as StaticBody3D
	if sb != null:
		sb.collision_layer = 0
		sb.collision_mask = 0

	# Cache the mesh instances so we can flip materials cheaply.
	_ghost_meshes.clear()
	_collect_meshes(ghost, _ghost_meshes)
	for mesh in _ghost_meshes:
		mesh.material_override = _invalid_material

	# Add the footprint area for overlap detection.
	_ghost_footprint = Area3D.new()
	_ghost_footprint.name = FOOTPRINT_NODE_NAME
	_ghost_footprint.collision_layer = 0
	_ghost_footprint.collision_mask = 7
	_ghost_footprint.monitoring = true
	_ghost_footprint.monitorable = false
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = definition.footprint_size
	shape.shape = box
	# Lift the footprint up so it sits on the ground rather than half-buried.
	shape.transform = Transform3D(Basis(), Vector3(0, definition.footprint_size.y * 0.5, 0))
	_ghost_footprint.add_child(shape)
	ghost.add_child(_ghost_footprint)

	scene_root.add_child(ghost)
	_ghost = ghost
	return true


func _destroy_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_ghost_footprint = null
	_ghost_meshes.clear()
	_has_ground_hit = false
	_is_valid = false


func _update_ghost_transform() -> void:
	if _ghost == null:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		_ghost.visible = false
		_has_ground_hit = false
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var direction: Vector3 = camera.project_ray_normal(mouse_pos)
	var space: PhysicsDirectSpaceState3D = _ghost.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + direction * 200.0
	)
	query.collision_mask = 1  # ground layer only
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty() or not (hit.collider is Node):
		_ghost.visible = false
		_has_ground_hit = false
		return
	var collider: Node = hit.collider
	if not collider.is_in_group(GROUND_GROUP):
		# The raycast hit something on layer 1 that isn't the ground
		# (e.g. the player). Treat as no ground hit so the ghost hides.
		_ghost.visible = false
		_has_ground_hit = false
		return
	_ghost.visible = true
	_ghost.global_position = hit.position
	_has_ground_hit = true


func _compute_validity() -> bool:
	if not _has_ground_hit:
		return false
	if _active_definition == null:
		return false
	if not ResourceManager.can_afford(_active_definition.cost):
		return false
	if _ghost_footprint == null:
		return false
	# Force the physics server to update overlap state for the freshly
	# moved area before we query it.
	for body in _ghost_footprint.get_overlapping_bodies():
		if body == null or not is_instance_valid(body):
			continue
		if body.is_in_group(GROUND_GROUP):
			continue
		return false
	return true


func _update_validity(is_valid: bool, force: bool) -> void:
	if not force and is_valid == _is_valid:
		return
	_is_valid = is_valid
	var material: StandardMaterial3D = _valid_material if is_valid else _invalid_material
	for mesh in _ghost_meshes:
		if mesh != null and is_instance_valid(mesh):
			mesh.material_override = material
	placement_validity_changed.emit(is_valid)


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			out.append(child)
		if child.get_child_count() > 0:
			_collect_meshes(child, out)


func _make_ghost_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _load_definitions() -> void:
	_definitions.clear()
	_by_id.clear()
	var dir: DirAccess = DirAccess.open(BUILDINGS_DIR)
	if dir == null:
		push_warning("BuildManager: cannot open %s" % BUILDINGS_DIR)
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path: String = BUILDINGS_DIR + file_name
			var loaded: Resource = load(path)
			var def: BuildingDefinition = loaded as BuildingDefinition
			if def == null:
				push_warning("BuildManager: %s is not a BuildingDefinition" % path)
			elif def.id == &"":
				push_warning("BuildManager: %s has empty id; skipping" % path)
			elif def.scene == null:
				push_warning("BuildManager: %s has no scene; skipping" % path)
			else:
				_definitions.append(def)
				_by_id[def.id] = def
		file_name = dir.get_next()
	dir.list_dir_end()
	_definitions.sort_custom(_compare_definitions)


func _compare_definitions(a: BuildingDefinition, b: BuildingDefinition) -> bool:
	if a.sort_order != b.sort_order:
		return a.sort_order < b.sort_order
	return a.display_name < b.display_name
