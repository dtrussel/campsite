class_name PostFx
extends CanvasLayer

## PostFx
##
## The full-screen look pass of feature 031: tilt-shift blur, warm
## split-tone grade and vignette (`shaders/post_tiltshift.gdshader`).
## It sits below every UI layer, so menus and the HUD stay sharp. In a
## run it follows TimeManager and cools the grade at night; the title
## backdrop passes a fixed `night_amount`. The blur can be switched off
## in the pause menu (saved in user://settings.cfg, section "video").

const SHADER: Shader = preload("res://shaders/post_tiltshift.gdshader")
const SETTINGS_PATH: String = "user://settings.cfg"

## phase -> how "night" the grade is.
const NIGHT_AMOUNT: Dictionary = {0: 0.0, 1: 0.45, 2: 1.0, 3: 0.25}

## Follow TimeManager phases (off for the title backdrop).
@export var follow_time: bool = true
@export var night_amount: float = 0.0

var _material: ShaderMaterial = null
var _tween: Tween = null


static func is_blur_enabled() -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return true
	return bool(config.get_value("video", "tilt_shift", true))


static func set_blur_enabled(enabled: bool) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)  # keep any other sections
	config.set_value("video", "tilt_shift", enabled)
	config.save(SETTINGS_PATH)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.call_group("post_fx", "refresh_settings")


func _ready() -> void:
	layer = -1
	add_to_group("post_fx")
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	rect.material = _material
	add_child(rect)
	refresh_settings()
	if follow_time:
		night_amount = NIGHT_AMOUNT.get(TimeManager.current_phase, 0.0)
		TimeManager.phase_changed.connect(_on_phase_changed)
	_material.set_shader_parameter("night_amount", night_amount)


func refresh_settings() -> void:
	_material.set_shader_parameter("blur_enabled", 1.0 if is_blur_enabled() else 0.0)


func _on_phase_changed(phase: int) -> void:
	var seconds: float = 3.0
	match phase:
		TimeManager.Phase.SUNSET:
			seconds = TimeManager.sunset_seconds
		TimeManager.Phase.DAWN:
			seconds = TimeManager.dawn_seconds
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void:
		night_amount = v
		_material.set_shader_parameter("night_amount", v)
	, night_amount, float(NIGHT_AMOUNT.get(phase, 0.0)), maxf(seconds, 0.1)).set_trans(Tween.TRANS_SINE)
