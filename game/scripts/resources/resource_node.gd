extends Area3D

## A gatherable resource node in the world. Yields resources when interacted with.

@export var resource_id: String = "wood"
@export var amount_per_gather: int = 3
@export var gather_time_seconds: float = 1.5
@export var total_charges: int = 5          # how many gathers before depleted
@export var respawn_time_seconds: float = 60.0

var _remaining_charges: int
var _is_depleted: bool = false
var _respawn_timer: float = 0.0

@onready var _mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	_remaining_charges = total_charges

func _process(delta: float) -> void:
	if _is_depleted:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()

func interact(_interactor: Node) -> void:
	if _is_depleted:
		return
	ResourceManager.add(resource_id, amount_per_gather)
	ProgressionManager.award_xp("player_boy", 1)
	_remaining_charges -= 1
	if _remaining_charges <= 0:
		_deplete()

func _deplete() -> void:
	_is_depleted = true
	_respawn_timer = respawn_time_seconds
	if _mesh:
		_mesh.visible = false

func _respawn() -> void:
	_is_depleted = false
	_remaining_charges = total_charges
	if _mesh:
		_mesh.visible = true
