extends NavigationRegion3D

## NavigationBaker
##
## Bakes the walkable area for right-click movement at runtime from the
## static colliders in the gameplay scene: the ground is walkable;
## resource nodes, buildings, the campfire and camp props are holes.
## Re-bakes (debounced, on a thread) whenever a building is placed or
## destroyed so paths route around new fences.

signal baked

const SOURCE_GROUP: StringName = &"nav_source"
const REBAKE_DELAY: float = 0.3

@export var half_extent: float = 21.0

var _pending: bool = false


func _ready() -> void:
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1 | 2 | 4  # ground, resources, buildings
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = SOURCE_GROUP
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.25
	mesh.agent_max_climb = 0.25
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.filter_baking_aabb = AABB(
		Vector3(-half_extent, -1.0, -half_extent), Vector3(half_extent * 2.0, 4.0, half_extent * 2.0)
	)
	navigation_mesh = mesh
	bake_finished.connect(func() -> void: baked.emit())
	BuildManager.building_placed.connect(_on_building_placed)
	# Bake once the whole scene (and its dressing) is in the tree.
	_request_bake.call_deferred()


func _request_bake() -> void:
	var scene: Node = get_tree().current_scene
	if scene != null and not scene.is_in_group(SOURCE_GROUP):
		scene.add_to_group(SOURCE_GROUP)
	if _pending:
		return
	_pending = true
	await get_tree().create_timer(REBAKE_DELAY, false).timeout
	_pending = false
	if is_inside_tree():
		if is_baking():
			await bake_finished
		bake_navigation_mesh(true)


func _on_building_placed(building: Node) -> void:
	if building.has_signal("destroyed"):
		building.destroyed.connect(func() -> void:
			# The building frees itself right after this signal.
			await get_tree().process_frame
			_request_bake()
		)
	_request_bake()
