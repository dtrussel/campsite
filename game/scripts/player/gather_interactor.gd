extends Area3D

## GatherInteractor
##
## Composition component attached as a child Area3D on the player.
## Tracks ResourceNodes currently within interaction range via
## body_entered / body_exited and exposes get_closest() for the
## player controller to call when the interact input is pressed.
##
## The interactor's collision_mask must include the layer used by
## ResourceNodes (layer 2 by convention).

signal interactable_entered(node: ResourceNode)
signal interactable_exited(node: ResourceNode)

var _nodes_in_range: Array[ResourceNode] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func get_closest() -> ResourceNode:
	var best: ResourceNode = null
	var best_distance_sq: float = INF
	for node in _nodes_in_range:
		if node == null or not is_instance_valid(node):
			continue
		if not node.is_gatherable:
			continue
		var d_sq: float = node.global_position.distance_squared_to(global_position)
		if d_sq < best_distance_sq:
			best_distance_sq = d_sq
			best = node
	return best


func contains(node: ResourceNode) -> bool:
	return node != null and _nodes_in_range.has(node)


func _on_body_entered(body: Node) -> void:
	var rn: ResourceNode = body as ResourceNode
	if rn == null:
		return
	if not _nodes_in_range.has(rn):
		_nodes_in_range.append(rn)
		interactable_entered.emit(rn)


func _on_body_exited(body: Node) -> void:
	var rn: ResourceNode = body as ResourceNode
	if rn == null:
		return
	if _nodes_in_range.has(rn):
		_nodes_in_range.erase(rn)
		interactable_exited.emit(rn)
