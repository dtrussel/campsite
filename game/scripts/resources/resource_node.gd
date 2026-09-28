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

var is_gatherable: bool = true
var _progress_label: Label3D = null

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

	_progress_label = Fx.make_hp_label(self, 2.2)
	_progress_label.visible = false
	set_process(false)


func _process(_delta: float) -> void:
	if _active_gather_actor == null or gather_time_seconds <= 0.0:
		return
	var done: float = 1.0 - _gather_timer.time_left / gather_time_seconds
	var filled: int = clampi(int(done * 10.0), 0, 10)
	_progress_label.text = "Gathering %s%s" % ["|".repeat(filled), ".".repeat(10 - filled)]


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
	var pickup: String = "+%d %s" % [yield_amount, definition.display_name]
	if bonus_definition != null and bonus_amount > 0:
		ResourceManager.add(bonus_definition.id, bonus_amount)
		pickup += "  +%d %s" % [bonus_amount, bonus_definition.display_name]
	Fx.float_text(self, pickup, definition.ui_color, 1.8)
	ProgressionManager.award_xp(actor, GATHER_XP_REWARD, &"gather")
	gathered.emit(actor, definition.id, yield_amount)
	_deplete()


func _show_progress(is_shown: bool) -> void:
	if _progress_label == null:
		return
	_progress_label.visible = is_shown
	_progress_label.modulate = Color(1, 1, 0.8)
	set_process(is_shown)


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
