extends CharacterBody3D

## PlayerController
##
## Phase 0 placeholder. WASD-driven movement in world space, no
## camera-relative input yet (the camera is fixed). State machine,
## gathering, building, and attacking are not implemented in
## Phase 0; they arrive in later phases per the roadmap.

@export var move_speed: float = 5.0
@export var acceleration: float = 20.0
@export var friction: float = 18.0


func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)

	var target_velocity: Vector3 = Vector3.ZERO
	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()
		target_velocity = Vector3(input_dir.x, 0.0, input_dir.y) * move_speed

	var rate: float = acceleration if target_velocity.length() > 0.0 else friction
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)

	# Keep grounded on the flat test world.
	velocity.y = 0.0
	move_and_slide()
