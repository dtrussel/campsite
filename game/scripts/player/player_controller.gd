extends CharacterBody3D

## Controls the player boy: movement, gathering interaction, build mode entry.

const CHARACTER_ID: String = "player_boy"

@export var move_speed: float = 5.0
@export var sprint_multiplier: float = 1.6
@export var gather_range: float = 2.0

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _interact_area: Area3D = $InteractArea

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y).normalized()

	var speed: float = move_speed
	if Input.is_action_pressed("sprint"):
		speed *= sprint_multiplier

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		_face_direction(direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()

func _try_interact() -> void:
	var overlapping: Array[Area3D] = _interact_area.get_overlapping_areas()
	for area in overlapping:
		if area.has_method("interact"):
			area.interact(self)
			return

func _face_direction(direction: Vector3) -> void:
	if direction.length_squared() > 0.0:
		var target_angle: float = atan2(direction.x, direction.z)
		rotation.y = target_angle
