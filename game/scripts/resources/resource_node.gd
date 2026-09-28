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

const GATHER_XP_REWARD: int = 1

@export var definition: ResourceDefinition
@export var yield_amount: int = 1
@export var gather_time_seconds: float = 1.5
@export var respawn_seconds: float = 20.0
## Optional second item granted on every gather (e.g. a tree also
## drops Leaves). Leave empty for single-yield nodes.
@export var bonus_definition: ResourceDefinition
@export var bonus_amount: int = 1
## Gatherer animation state (CharacterVisual clip key): "chop" for
## trees and rocks, "pick" for bushes.
@export var gather_animation: StringName = &"chop"
## Fx.burst kind played when a gather completes.
@export var gather_burst: StringName = &"wood"

var is_gatherable: bool = true
var _progress_bar: HealthBar3D = null

var _active_gather_actor: Node = null
var _gather_timer: Timer
var _respawn_timer: Timer

@onready var _visual_root: Node3D = $Visual
## Optional stump / leftover shown while depleted.
@onready var _depleted_visual: Node3D = get_node_or_null("DepletedVisual") as Node3D


func _ready() -> void:
	_gather_timer = Timer.new()
	_gather_timer.one_shot = true
	_gather_timer.timeout.connect(_on_gather_complete)
	add_child(_gather_timer)

	_respawn_timer = Timer.new()
	_respawn_timer.one_shot = true
	_respawn_timer.timeout.connect(_on_respawn_complete)
	add_child(_respawn_timer)

	_progress_bar = HealthBar3D.attach(self, 2.4, "structure", 1.0)
	_progress_bar.visible = false
	set_process(false)


func _process(_delta: float) -> void:
	if _active_gather_actor == null or gather_time_seconds <= 0.0:
		return
	var done: float = 1.0 - _gather_timer.time_left / gather_time_seconds
	_progress_bar.set_value(int(done * 100.0), 100)


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
	_show_progress(true)
	return true


func cancel_gather(actor: Node) -> void:
	if _active_gather_actor != actor:
		return
	_gather_timer.stop()
	_active_gather_actor = null
	_show_progress(false)


func _on_gather_complete() -> void:
	if _active_gather_actor == null or definition == null:
		return
	var actor: Node = _active_gather_actor
	_active_gather_actor = null
	_show_progress(false)
	ResourceManager.add(definition.id, yield_amount)
	var popup_anchor: Node3D = actor as Node3D if actor is Node3D else self
	Fx.icon_popup(popup_anchor, definition.icon, "+%d" % yield_amount, Color(1, 1, 0.85), false, 2.6, -0.35)
	if bonus_definition != null and bonus_amount > 0:
		ResourceManager.add(bonus_definition.id, bonus_amount)
		Fx.icon_popup(popup_anchor, bonus_definition.icon, "+%d" % bonus_amount, Color(1, 1, 0.85), false, 2.1, 0.5)
	Fx.burst(gather_burst, global_position + Vector3(0, 0.8, 0))
	ProgressionManager.award_xp(actor, GATHER_XP_REWARD, &"gather")
	gathered.emit(actor, definition.id, yield_amount)
	_deplete()


func _show_progress(is_shown: bool) -> void:
	if _progress_bar == null:
		return
	_progress_bar.visible = is_shown
	if is_shown:
		_progress_bar.set_value(0, 100)
	set_process(is_shown)


func _deplete() -> void:
	is_gatherable = false
	if _visual_root != null:
		_visual_root.visible = false
	if _depleted_visual != null:
		_depleted_visual.visible = true
	depleted.emit()
	if respawn_seconds > 0.0:
		_respawn_timer.start(respawn_seconds)


func _on_respawn_complete() -> void:
	is_gatherable = true
	if _visual_root != null:
		_visual_root.visible = true
		_visual_root.scale = Vector3.ONE * 0.2
		create_tween().tween_property(_visual_root, "scale", Vector3.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _depleted_visual != null:
		_depleted_visual.visible = false
	respawned.emit()
