class_name NavSteer
extends RefCounted

## NavSteer
##
## Path following on the world's navigation mesh, shared by the hero
## and the companion, so neither walks in a straight line into a prop
## and gets stuck behind it.


## A NavigationAgent3D tuned for the kids, added as a child of `body`.
static func make_agent(body: Node3D, radius: float = 0.35) -> NavigationAgent3D:
	var agent: NavigationAgent3D = NavigationAgent3D.new()
	agent.radius = radius
	agent.path_desired_distance = 0.4
	agent.target_desired_distance = 0.3
	agent.path_max_distance = 2.0
	# The baked surface sits a voxel or two above the ground plane.
	agent.path_height_offset = 0.5
	body.add_child(agent)
	return agent


## Velocity from `body` toward `goal` at `speed`, following the agent's
## path once the map has synced (straight at the goal before that).
static func velocity(agent: NavigationAgent3D, body: Node3D, goal: Vector3, speed: float) -> Vector3:
	var next: Vector3 = goal
	if agent != null and NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0:
		if not agent.is_navigation_finished():
			next = agent.get_next_path_position()
	var to_next: Vector3 = next - body.global_position
	to_next.y = 0.0
	if to_next.length() < 0.05:
		to_next = goal - body.global_position
		to_next.y = 0.0
	if to_next.length() < 0.01:
		return Vector3.ZERO
	return to_next.normalized() * speed


## The closest point on the agent's navigation map to `point` (the
## point itself before the map has synced).
static func closest_point(agent: NavigationAgent3D, point: Vector3) -> Vector3:
	var map: RID = agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return point
	var snapped: Vector3 = NavigationServer3D.map_get_closest_point(map, point)
	return Vector3(snapped.x, point.y, snapped.z)
