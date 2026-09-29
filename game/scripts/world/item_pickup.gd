class_name ItemPickup
extends Node3D

## ItemPickup
##
## A loot drop lying on the ground (feature 017: Glow Shards from
## imps). It bobs and glows; Leo or Nela collect it just by walking
## close. Within `magnet_radius` of Leo it drifts toward him, so small
## players do not have to line up exactly.

@export var item_id: StringName = &"glow_shards"
@export var amount: int = 1
@export var collect_radius: float = 1.1
@export var magnet_radius: float = 3.0
@export var magnet_speed: float = 5.0

var _time: float = 0.0
var _collected: bool = false

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group("pickups")
	_time = randf() * TAU
	# Pop out of the imp: a quick hop from small to full size.
	_visual.scale = Vector3.ONE * 0.2
	create_tween().tween_property(_visual, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if _collected:
		return
	if ResourceManager.is_full(item_id):
		# Stash full: wait on the ground (bobbing) until there is room.
		_time += delta
		_visual.position.y = 0.35 + sin(_time * 3.0) * 0.12
		return
	_time += delta
	_visual.position.y = 0.35 + sin(_time * 3.0) * 0.12
	_visual.rotation.y += delta * 1.6
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	var collectors: Array = get_tree().get_nodes_in_group("companions")
	if player != null:
		collectors.append(player)
		var to_player: Vector3 = player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() < magnet_radius and player.get("is_knocked_out") != true:
			global_position += to_player.normalized() * minf(magnet_speed * delta, to_player.length())
	for node in collectors:
		var collector: Node3D = node as Node3D
		if collector == null or collector.get("is_knocked_out") == true:
			continue
		var offset: Vector3 = collector.global_position - global_position
		offset.y = 0.0
		if offset.length() <= collect_radius:
			_collect(collector)
			return


func _collect(collector: Node3D) -> void:
	_collected = true
	ResourceManager.add(item_id, amount)
	GameManager.record(&"shards" if item_id == &"glow_shards" else &"gathered", amount)
	var definition: ResourceDefinition = ResourceManager.get_definition(item_id)
	Fx.icon_popup(collector, definition.icon if definition != null else null, "+%d" % amount, Color(0.7, 1.0, 1.0))
	Fx.burst(&"shard", global_position + Vector3(0, 0.4, 0))
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE * 0.01, 0.2)
	tween.tween_callback(queue_free)
