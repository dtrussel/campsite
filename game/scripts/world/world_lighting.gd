extends Node

## WorldLighting
##
## Blends sun, ambient light, sky and fog between four hand-picked
## palettes as TimeManager changes phase: golden-hour day (strong low
## sun, low warm ambient so shadows read warm brown), orange-pink sunset,
## blue moonlit night (the campfire becomes the key light), and a soft
## dawn. Transitions tween over the phase so the sky visibly turns.

@export var sun_path: NodePath
@export var environment_path: NodePath
@export var campfire_path: NodePath

## phase -> palette. Angles are the sun's pitch in degrees.
const PALETTES: Dictionary = {
	0: {  # DAY: golden hour (concept 01/02)
		"sun_color": Color(1.0, 0.84, 0.6), "sun_energy": 1.25, "sun_pitch": -36.0,
		"ambient": Color(0.62, 0.48, 0.42), "ambient_energy": 0.16,
		"sky_top": Color(0.36, 0.56, 0.86), "sky_horizon": Color(0.98, 0.84, 0.62),
		"fog": Color(0.98, 0.78, 0.55), "fog_density": 0.004, "fire": 0.75,
	},
	1: {  # SUNSET: deep amber
		"sun_color": Color(1.0, 0.5, 0.24), "sun_energy": 1.25, "sun_pitch": -16.0,
		"ambient": Color(0.74, 0.44, 0.42), "ambient_energy": 0.34,
		"sky_top": Color(0.3, 0.24, 0.5), "sky_horizon": Color(1.0, 0.52, 0.28),
		"fog": Color(0.88, 0.48, 0.36), "fog_density": 0.008, "fire": 1.05,
	},
	2: {  # NIGHT: deep teal-blue, the fire is the key light (concept 03)
		"sun_color": Color(0.5, 0.62, 1.0), "sun_energy": 0.36, "sun_pitch": -62.0,
		"ambient": Color(0.14, 0.2, 0.38), "ambient_energy": 0.55,
		"sky_top": Color(0.02, 0.04, 0.1), "sky_horizon": Color(0.08, 0.14, 0.26),
		"fog": Color(0.05, 0.09, 0.17), "fog_density": 0.014, "fire": 1.6,
	},
	3: {  # DAWN
		"sun_color": Color(1.0, 0.76, 0.56), "sun_energy": 1.1, "sun_pitch": -24.0,
		"ambient": Color(0.62, 0.5, 0.5), "ambient_energy": 0.34,
		"sky_top": Color(0.38, 0.48, 0.8), "sky_horizon": Color(1.0, 0.74, 0.56),
		"fog": Color(0.85, 0.7, 0.62), "fog_density": 0.008, "fire": 0.9,
	},
}

var _sun: DirectionalLight3D = null
var _env: Environment = null
var _sky: ProceduralSkyMaterial = null
var _fire: Node = null
var _current: Dictionary = {}
var _tween: Tween = null


func _ready() -> void:
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	var world_env: WorldEnvironment = get_node_or_null(environment_path) as WorldEnvironment
	if world_env != null:
		_env = world_env.environment
		if _env != null and _env.sky != null:
			_sky = _env.sky.sky_material as ProceduralSkyMaterial
	_fire = get_node_or_null(campfire_path)
	if _fire != null:
		_fire = _fire.find_child("Fire", true, false)
	TimeManager.phase_changed.connect(_on_phase_changed)
	_current = (PALETTES[TimeManager.current_phase] as Dictionary).duplicate()
	_apply(_current)


func _on_phase_changed(phase: int) -> void:
	var seconds: float = 3.0
	match phase:
		TimeManager.Phase.SUNSET:
			seconds = TimeManager.sunset_seconds
		TimeManager.Phase.DAWN:
			seconds = TimeManager.dawn_seconds
	blend_to(phase, seconds)


func blend_to(phase: int, seconds: float) -> void:
	var from: Dictionary = _current.duplicate()
	var to: Dictionary = PALETTES.get(phase, PALETTES[0])
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(t: float) -> void:
		for key in to.keys():
			var a: Variant = from.get(key, to[key])
			_current[key] = lerp(a, to[key], t)
		_apply(_current)
	, 0.0, 1.0, maxf(seconds, 0.1)).set_trans(Tween.TRANS_SINE)


func _apply(p: Dictionary) -> void:
	if _sun != null:
		_sun.light_color = p["sun_color"]
		_sun.light_energy = p["sun_energy"]
		_sun.rotation_degrees.x = p["sun_pitch"]
	if _env != null:
		_env.ambient_light_color = p["ambient"]
		_env.ambient_light_energy = p["ambient_energy"]
		_env.fog_light_color = p["fog"]
		_env.fog_density = p["fog_density"]
	if _sky != null:
		_sky.sky_top_color = p["sky_top"]
		_sky.sky_horizon_color = p["sky_horizon"]
		_sky.ground_horizon_color = (p["sky_horizon"] as Color).darkened(0.3)
	if _fire != null and _fire.has_method("set_intensity"):
		_fire.set_intensity(p["fire"])
