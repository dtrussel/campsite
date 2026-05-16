class_name ResourceNode
extends StaticBody3D

## ResourceNode
##
## Shared behaviour for any gatherable world object (tree, rock, berry
## bush, ...). Holds a ResourceDefinition and gather/respawn timings as
## exported properties so each .tscn variant is configured by data.
##
## The node — not the player — calls ResourceManager.add() when its
## internal gather timer fires; the player just listens for `gathered`
## to leave its GATHERING state.

signal gathered(actor: Node, id: StringName, amount: int)
signal depleted
signal respawned

@export var definition: ResourceDefinition
@export var yield_amount: int = 1
@export var gather_time_seconds: float = 1.5
@export var respawn_seconds: float = 20.0

var is_gatherable: bool = true

var _active_gather_actor: Node = null
var _gather_timer: Timer
var _respawn_timer: Timer

@onready var _visual_root: Node3D = $Visual


func _ready() -> void:
	_gather_timer = Timer.new()
	_gather_timer.one_shot = true
	_gather_timer.timeout.connect(_on_gather_complete)
	add_child(_gather_timer)

	_respawn_timer = Timer.new()
	_respawn_timer.one_shot = true
	_respawn_timer.timeout.connect(_on_respawn_complete)
	add_child(_respawn_timer)


func begin_gather(actor: Node) -> bool:
	if not is_gatherable:
		return false
	if _active_gather_actor != null:
		return false
	if definition == null:
		push_warning("ResourceNode '%s' has no definition" % name)
		return false
	_active_gather_actor = actor
	_gather_timer.start(gather_time_seconds)
	return true


func cancel_gather(actor: Node) -> void:
	if _active_gather_actor != actor:
		return
	_gather_timer.stop()
	_active_gather_actor = null


func _on_gather_complete() -> void:
	if _active_gather_actor == null or definition == null:
		return
	var actor: Node = _active_gather_actor
	_active_gather_actor = null
	ResourceManager.add(definition.id, yield_amount)
	gathered.emit(actor, definition.id, yield_amount)
	_deplete()


func _deplete() -> void:
	is_gatherable = false
	if _visual_root != null:
		_visual_root.visible = false
	depleted.emit()
	if respawn_seconds > 0.0:
		_respawn_timer.start(respawn_seconds)


func _on_respawn_complete() -> void:
	is_gatherable = true
	if _visual_root != null:
		_visual_root.visible = true
	respawned.emit()
