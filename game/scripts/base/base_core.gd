class_name BaseCore
extends StaticBody3D

## BaseCore
##
## Heart of the camp. Mobs prefer this as their final target. When HP
## reaches zero, the campsite is considered lost. Phase 0 left the
## campfire as a visual-only object; this script wires up health and
## the matching signals.

signal damaged(new_hp: int)
signal repaired(new_hp: int)
signal destroyed

@export var max_hp: int = 150
## HP restored by one hammer tap or one "Feed the fire".
@export var repair_per_tap: int = 20
## Stone Hearth upgrade (feature 017): extra max HP and the clay ring.
@export var hearth_bonus_hp: int = 75

const HEARTH_SCENE: String = "res://assets/custom/hearth_ring.glb"

var has_hearth: bool = false

var current_hp: int = 0
var is_destroyed: bool = false
var _hp_bar: HealthBar3D = null
var _last_logged_quarter: int = 4


func _ready() -> void:
	add_to_group(Repair.GROUP)
	current_hp = max_hp
	_hp_bar = HealthBar3D.attach(self, 2.3, "structure", 1.8)
	_refresh_hp_label.call_deferred()


func take_damage(amount: int, _source: Node = null) -> void:
	if amount <= 0 or is_destroyed:
		return
	current_hp = max(0, current_hp - amount)
	damaged.emit(current_hp)
	Fx.flash(self)
	AudioManager.play_sfx(&"camp_hit", global_position)
	_refresh_hp_label()
	_log_quarters()
	if current_hp == 0:
		is_destroyed = true
		destroyed.emit()


func _refresh_hp_label() -> void:
	if _hp_bar != null:
		_hp_bar.set_value(current_hp, max_hp)


func _log_quarters() -> void:
	var quarter: int = int(ceil(float(current_hp) / float(max_hp) * 4.0))
	if quarter < _last_logged_quarter:
		_last_logged_quarter = quarter
		PlaytestLog.write("campfire_hp %d/%d day=%d" % [current_hp, max_hp, TimeManager.day_number])


func get_max_hp() -> int:
	return max_hp


func get_missing_hp() -> int:
	return 0 if is_destroyed else maxi(0, max_hp - current_hp)


func repair(amount: int) -> void:
	if amount <= 0 or is_destroyed:
		return
	current_hp = min(max_hp, current_hp + amount)
	repaired.emit(current_hp)
	_refresh_hp_label()


## Lays the clay-brick ring: +hearth_bonus_hp max HP and a full heal.
func build_hearth() -> void:
	if has_hearth or is_destroyed:
		return
	has_hearth = true
	max_hp += hearth_bonus_hp
	current_hp = max_hp
	var ring: Node3D = (load(HEARTH_SCENE) as PackedScene).instantiate() as Node3D
	ring.name = "HearthRing"
	Stylize.apply(ring, "prop")
	add_child(ring)
	ring.scale = Vector3(0.2, 0.2, 0.2)
	var tween: Tween = create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.burst(&"level_up", global_position)
	Fx.float_text(self, "STONE HEARTH!", Color(1.0, 0.8, 0.45), 2.6)
	repaired.emit(current_hp)
	_refresh_hp_label()
	PlaytestLog.write("stone_hearth_built day=%d" % TimeManager.day_number)
