class_name SnapTrap
extends Building

## SnapTrap
##
## A wooden snap trap (feature 017). Imps walk right over it (it blocks
## nothing): the first imp to step on the pad gets snapped, hurt and
## held in place for a moment, then the jaws re-arm. Each snap uses one
## charge (the trap's HP bar); after the last one it breaks. Traps are
## rebuilt, not repaired.

const OPEN_DEGREES: float = 8.0
const CLOSED_DEGREES: float = 84.0

@export var trigger_radius: float = 0.8
@export var snap_damage: int = 10
@export var hold_seconds: float = 2.5
@export var rearm_seconds: float = 1.6

var _armed: bool = true

@onready var _jaws: Array[Node3D] = [$Visual/JawA as Node3D, $Visual/JawB as Node3D]


func _ready() -> void:
	super()
	_set_jaws(OPEN_DEGREES)
	set_physics_process(not has_meta(&"build_ghost"))


func _physics_process(_delta: float) -> void:
	if not _armed:
		return
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob: Node3D = node as Node3D
		if mob == null or (mob.has_method("is_stunned") and mob.is_stunned()):
			continue
		var offset: Vector3 = mob.global_position - global_position
		offset.y = 0.0
		if offset.length() <= trigger_radius:
			_snap(mob)
			return


func _snap(mob: Node3D) -> void:
	_armed = false
	# Kills by a trap count as Leo's (he built it).
	var credit: Node = get_tree().get_first_node_in_group("player")
	if mob.has_method("stun"):
		mob.stun(hold_seconds)
	mob.take_damage(snap_damage, credit if credit != null else self)
	AudioManager.play_sfx(&"trap_snap", global_position)
	Fx.shake(0.06)
	GameManager.record(&"trap_snaps")
	current_hp = maxi(0, current_hp - 1)
	_refresh_hp_label()
	var tween: Tween = create_tween()
	tween.tween_method(_set_jaws, OPEN_DEGREES, CLOSED_DEGREES, 0.08)
	tween.tween_interval(rearm_seconds)
	if current_hp == 0:
		tween.tween_callback(_break)
	else:
		tween.tween_method(_set_jaws, CLOSED_DEGREES, OPEN_DEGREES, 0.35)
		tween.tween_callback(func() -> void: _armed = true)


func _break() -> void:
	Fx.burst(&"build", global_position + Vector3(0, 0.2, 0))
	destroyed.emit()
	PlaytestLog.write("trap_used_up day=%d" % TimeManager.day_number)
	queue_free()


func _set_jaws(degrees: float) -> void:
	for jaw in _jaws:
		if jaw != null:
			jaw.rotation.z = deg_to_rad(degrees)
