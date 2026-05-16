extends Node

## GameManager
##
## Top-level coordinator. Owns high-level run state and dispatches
## companion-task hotkeys to whichever companions are alive. Also
## tracks whether the camp has been destroyed.

signal day_number_changed(new_day: int)
signal camp_destroyed
signal companion_task_changed(companion: Node, task: int)

var current_day: int = 1
var is_camp_destroyed: bool = false


func _ready() -> void:
	if TimeManager and not TimeManager.day_started.is_connected(_on_day_started):
		TimeManager.day_started.connect(_on_day_started)
	# Defer hooking the base core; it lives in the scene, not in the
	# autoload tree, so its _ready hasn't run yet at autoload _ready.
	call_deferred("_hook_base_core")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("assign_idle"):
		_assign_to_all_companions(0)
	elif event.is_action_pressed("assign_follow"):
		_assign_to_all_companions(1)
	elif event.is_action_pressed("assign_guard"):
		_assign_to_all_companions(2)
	elif event.is_action_pressed("assign_gather"):
		_assign_to_all_companions(3)


func _on_day_started(day_number: int) -> void:
	current_day = day_number
	day_number_changed.emit(current_day)


func _assign_to_all_companions(task: int) -> void:
	for companion in get_tree().get_nodes_in_group("companions"):
		if companion.has_method("set_task"):
			companion.set_task(task)
			companion_task_changed.emit(companion, task)


func _hook_base_core() -> void:
	for node in get_tree().get_nodes_in_group("base_core"):
		if node.has_signal("destroyed") and not node.destroyed.is_connected(_on_camp_destroyed):
			node.destroyed.connect(_on_camp_destroyed)


func _on_camp_destroyed() -> void:
	if is_camp_destroyed:
		return
	is_camp_destroyed = true
	camp_destroyed.emit()
