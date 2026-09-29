extends Node3D

## TitleBackdrop
##
## Live 3D scene behind the title menu: the camp at dusk, the boy and
## his sibling sitting by the fire, shadow minions lurking at the tree
## line, and a slow orbiting camera. Purely decorative - no gameplay
## nodes, so nothing here reacts to input or the run state.

const GROUND_MATERIAL: Material = preload("res://assets/materials/painted_ground.tres")
const CAMPFIRE_SCENE: PackedScene = preload("res://scenes/base/CampfireCore.tscn")
const ASSETS: String = "res://assets/"

@export var orbit_speed: float = 0.05
@export var orbit_radius: float = 12.0
@export var orbit_height: float = 6.5

var _camera: Camera3D = null
var _angle: float = 0.6


func _ready() -> void:
	_build_environment()
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(120, 120)
	ground.mesh = plane
	ground.material_override = GROUND_MATERIAL
	ground.set_meta(&"stylized", "skip")
	add_child(ground)

	var style: Node = load("res://scripts/world/style_director.gd").new()
	add_child(style)
	var dressing: Node3D = load("res://scripts/world/world_dressing.gd").new()
	dressing.grass_count = 2600
	add_child(dressing)

	var fire: Node3D = CAMPFIRE_SCENE.instantiate()
	fire.remove_from_group("base_core")
	add_child(fire)
	for child in fire.get_children():
		if child is HealthBar3D:
			child.queue_free()

	_character("custom/leo.glb", 0.7, "hero", Vector3(1.5, 0, 1.0), [], "Sit_Floor_Idle")
	_character("custom/nela.glb", 0.65, "hero", Vector3(-1.4, 0, 1.2), [], "Sit_Floor_Idle")
	for spot in [Vector3(-7.5, 0, -8.0), Vector3(-5.0, 0, -9.5), Vector3(8.0, 0, -7.0)]:
		_character("custom/shadow_imp.glb", 0.62, "shadow", spot, [], "Imp_Idle")

	_camera = Camera3D.new()
	_camera.fov = 42.0
	_camera.far = 200.0
	add_child(_camera)
	_camera.make_current()
	_update_camera(0.0)


func _process(delta: float) -> void:
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	_angle += orbit_speed * delta
	_camera.position = Vector3(sin(_angle) * orbit_radius, orbit_height, cos(_angle) * orbit_radius)
	_camera.look_at(Vector3(0, 1.0, 0))


func _character(path: String, model_scale: float, profile: String, position: Vector3, hidden: Array, clip: String) -> void:
	var visual: CharacterVisual = CharacterVisual.new()
	visual.model_scene = load(ASSETS + path)
	visual.model_scale = model_scale
	visual.hidden_parts = PackedStringArray(hidden)
	visual.style = profile
	visual.clips = {&"idle": clip}
	visual.position = position
	add_child(visual)
	visual.face_instantly(-position)


func _build_environment() -> void:
	var dusk: Dictionary = {
		"sun_color": Color(1.0, 0.5, 0.35), "sun_energy": 0.55,
		"ambient": Color(0.38, 0.3, 0.5), "ambient_energy": 0.55,
		"sky_top": Color(0.08, 0.08, 0.25), "sky_horizon": Color(0.85, 0.42, 0.35),
		"fog": Color(0.35, 0.22, 0.35),
	}
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = dusk["sky_top"]
	sky_material.sky_horizon_color = dusk["sky_horizon"]
	sky_material.ground_horizon_color = (dusk["sky_horizon"] as Color).darkened(0.3)
	sky_material.ground_bottom_color = Color(0.05, 0.05, 0.08)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = dusk["ambient"]
	env.ambient_light_energy = dusk["ambient_energy"]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_light_color = dusk["fog"]
	env.fog_density = 0.018
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.2
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-18, 60, 0)
	sun.light_color = dusk["sun_color"]
	sun.light_energy = dusk["sun_energy"]
	sun.shadow_enabled = true
	add_child(sun)
