extends CharacterBody3D

## PlayerController
##
## WASD movement plus a simple IDLE / MOVING / GATHERING state
## machine. When `interact` is pressed and the GatherInteractor has
## a ResourceNode in range, the player enters GATHERING, freezes in
## place, and waits for the node's `gathered` signal. Movement input
## or losing the node mid-gather cancels.

enum PlayerState { IDLE, MOVING, GATHERING }

@export var move_speed: float = 5.0
@export var acceleration: float = 20.0
@export var friction: float = 18.0

@onready var _interactor: Node = $GatherInteractor

var _state: int = PlayerState.IDLE
var _active_node: ResourceNode = null


func _ready() -> void:
	if _interactor != null and _interactor.has_signal("interactable_exited"):
		_interactor.interactable_exited.connect(_on_interactor_exited)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_begin_gather()


func _physics_process(delta: float) -> void:
	if _state == PlayerState.GATHERING:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var input_dir: Vector2 = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)

	var target_velocity: Vector3 = Vector3.ZERO
	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()
		target_velocity = Vector3(input_dir.x, 0.0, input_dir.y) * move_speed
		_state = PlayerState.MOVING
	else:
		_state = PlayerState.IDLE

	var rate: float = acceleration if target_velocity.length() > 0.0 else friction
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)
	velocity.y = 0.0
	move_and_slide()


func _try_begin_gather() -> void:
	if _state == PlayerState.GATHERING:
		return
	if _interactor == null:
		return
	var node: ResourceNode = _interactor.get_closest()
	if node == null:
		return
	if not node.begin_gather(self):
		return
	_active_node = node
	if not node.gathered.is_connected(_on_node_gathered):
		node.gathered.connect(_on_node_gathered)
	_state = PlayerState.GATHERING
	velocity = Vector3.ZERO


func _cancel_active_gather() -> void:
	if _active_node != null:
		if _active_node.gathered.is_connected(_on_node_gathered):
			_active_node.gathered.disconnect(_on_node_gathered)
		_active_node.cancel_gather(self)
		_active_node = null
	if _state == PlayerState.GATHERING:
		_state = PlayerState.IDLE


func _on_node_gathered(actor: Node, _id: StringName, _amount: int) -> void:
	if actor != self:
		return
	if _active_node != null and _active_node.gathered.is_connected(_on_node_gathered):
		_active_node.gathered.disconnect(_on_node_gathered)
	_active_node = null
	_state = PlayerState.IDLE


func _on_interactor_exited(node: ResourceNode) -> void:
	if node == _active_node:
		_cancel_active_gather()


func _process(_delta: float) -> void:
	if _state != PlayerState.GATHERING:
		return
	var input_dir: Vector2 = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	if input_dir.length() > 0.0:
		_cancel_active_gather()
