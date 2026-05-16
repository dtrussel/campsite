extends Node

## WorldLighting
##
## Snaps the sun and ambient palette between day and night on phase
## transitions. Lives in TestWorld next to the DirectionalLight3D and
## WorldEnvironment.

@export var sun_path: NodePath
@export var environment_path: NodePath

@export var day_sun_color: Color = Color(1, 0.96, 0.86, 1)
@export var day_sun_energy: float = 1.1
@export var night_sun_color: Color = Color(0.4, 0.45, 0.7, 1)
@export var night_sun_energy: float = 0.18

@export var day_ambient_color: Color = Color(0.65, 0.7, 0.78, 1)
@export var day_ambient_energy: float = 0.6
@export var night_ambient_color: Color = Color(0.18, 0.2, 0.35, 1)
@export var night_ambient_energy: float = 0.3

var _sun: DirectionalLight3D = null
var _env: WorldEnvironment = null


func _ready() -> void:
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	_env = get_node_or_null(environment_path) as WorldEnvironment
	if TimeManager and not TimeManager.phase_changed.is_connected(_on_phase_changed):
		TimeManager.phase_changed.connect(_on_phase_changed)
	_apply_phase(TimeManager.current_phase if TimeManager else 0)


func _on_phase_changed(phase: int) -> void:
	_apply_phase(phase)


func _apply_phase(phase: int) -> void:
	var is_night: bool = phase == TimeManager.Phase.NIGHT or phase == TimeManager.Phase.SUNSET
	if _sun != null:
		_sun.light_color = night_sun_color if is_night else day_sun_color
		_sun.light_energy = night_sun_energy if is_night else day_sun_energy
	if _env != null and _env.environment != null:
		_env.environment.ambient_light_color = (
			night_ambient_color if is_night else day_ambient_color
		)
		_env.environment.ambient_light_energy = (
			night_ambient_energy if is_night else day_ambient_energy
		)
