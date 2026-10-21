class_name PostFx
extends CanvasLayer

## PostFx
##
## The full-screen look pass of feature 031: tilt-shift blur, warm
## split-tone grade and vignette (`shaders/post_tiltshift.gdshader`).
## It sits below every UI layer, so menus and the HUD stay sharp. In a
## run it follows TimeManager and cools the grade at night; the title
## backdrop passes a fixed `night_amount`. The blur has three levels in
## the pause menu, Off / Soft / Strong (saved in user://settings.cfg,
## section "video"); Soft is the default since playtest 1 (044). The
## camera moves the crisp band with its zoom (`set_focus_center`).

const SHADER: Shader = preload("res://shaders/post_tiltshift.gdshader")
const SETTINGS_PATH: String = "user://settings.cfg"

## phase -> how "night" the grade is.
const NIGHT_AMOUNT: Dictionary = {0: 0.0, 1: 0.45, 2: 1.0, 3: 0.25}

enum Blur { OFF, SOFT, STRONG }
const BLUR_NAMES: PackedStringArray = ["Off", "Soft", "Strong"]
## level -> shader parameters (Strong is the feature 031 look).
const BLUR_PARAMS: Dictionary = {
	Blur.SOFT: {"max_radius": 3.5, "focus_band": 0.2, "falloff": 0.45, "bottom_boost": 1.0, "haze": 0.02},
	Blur.STRONG: {"max_radius": 7.0, "focus_band": 0.12, "falloff": 0.32, "bottom_boost": 1.2, "haze": 0.04},
}

## Follow TimeManager phases (off for the title backdrop).
@export var follow_time: bool = true
@export var night_amount: float = 0.0

var _material: ShaderMaterial = null
var _tween: Tween = null


## The saved blur level. A pre-044 `tilt_shift = false` reads as Off.
static func blur_level() -> int:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return Blur.SOFT
	if config.has_section_key("video", "blur_level"):
		return clampi(int(config.get_value("video", "blur_level")), Blur.OFF, Blur.STRONG)
	return Blur.SOFT if bool(config.get_value("video", "tilt_shift", true)) else Blur.OFF


static func set_blur_level(level: int) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)  # keep any other sections
	config.set_value("video", "blur_level", clampi(level, Blur.OFF, Blur.STRONG))
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
	var level: int = blur_level()
	_material.set_shader_parameter("blur_enabled", 0.0 if level == Blur.OFF else 1.0)
	var params: Dictionary = BLUR_PARAMS.get(level, BLUR_PARAMS[Blur.SOFT])
	for key: String in params:
		_material.set_shader_parameter(key, params[key])


## Screen y of the crisp band (the camera lowers it as it tilts).
func set_focus_center(y: float) -> void:
	_material.set_shader_parameter("focus_center", y)


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
