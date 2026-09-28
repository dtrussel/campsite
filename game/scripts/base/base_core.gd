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

var current_hp: int = 0
var is_destroyed: bool = false
var _hp_bar: HealthBar3D = null
var _last_logged_quarter: int = 4


func _ready() -> void:
	current_hp = max_hp
	_hp_bar = HealthBar3D.attach(self, 2.3, "structure", 1.8)
	_refresh_hp_label.call_deferred()


func take_damage(amount: int, _source: Node = null) -> void:
	if amount <= 0 or is_destroyed:
		return
	current_hp = max(0, current_hp - amount)
	damaged.emit(current_hp)
	Fx.flash(self)
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


func repair(amount: int) -> void:
	if amount <= 0 or is_destroyed:
		return
	current_hp = min(max_hp, current_hp + amount)
	repaired.emit(current_hp)
	_refresh_hp_label()
