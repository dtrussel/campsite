class_name HealthBar3D
extends Node3D

## HealthBar3D
##
## Floating LoL-style health bar above a unit. The fill snaps to the
## new value; a pale trail drains after it so hits read clearly.
## Styles: "ally" (green), "hero" (green, with level badge),
## "enemy" (red), "structure" (gold, for the campfire and buildings).

const SHADER: Shader = preload("res://shaders/health_bar.gdshader")
const STYLES: Dictionary = {
	"hero": [Color(0.2, 0.78, 0.3), Color(0.55, 1.0, 0.5)],
	"ally": [Color(0.2, 0.7, 0.4), Color(0.5, 0.95, 0.65)],
	"enemy": [Color(0.78, 0.12, 0.12), Color(1.0, 0.42, 0.35)],
	"structure": [Color(0.85, 0.6, 0.15), Color(1.0, 0.86, 0.45)],
}

@export var width: float = 1.2
@export var height: float = 0.17
@export var style: String = "ally"
## Hide while at full health (buildings).
@export var hide_when_full: bool = false

var _material: ShaderMaterial = null
var _level_label: Label3D = null
var _fill: float = 1.0
var _trail: float = 1.0
var _max: int = 1
var _trail_delay: float = 0.0


func _ready() -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(width, height)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.render_priority = 10
	var colors: Array = STYLES.get(style, STYLES["ally"])
	_material.set_shader_parameter("fill_color", colors[0])
	_material.set_shader_parameter("fill_color_top", colors[1])
	quad.material = _material
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.set_meta(&"stylized", "skip")
	add_child(mesh)
	if style == "hero":
		_level_label = Label3D.new()
		_level_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_level_label.no_depth_test = true
		_level_label.render_priority = 11
		_level_label.font = Fx.bold_font()
		_level_label.outline_modulate = Color(0.05, 0.03, 0.01)
		_level_label.font_size = 40
		_level_label.pixel_size = 0.006
		_level_label.outline_size = 10
		_level_label.modulate = Color(1.0, 0.9, 0.6)
		_level_label.position = Vector3(-width * 0.5 - 0.14, 0, 0)
		_level_label.text = "1"
		add_child(_level_label)


func set_value(current: int, maximum: int) -> void:
	_max = maxi(1, maximum)
	var new_fill: float = clampf(float(current) / float(_max), 0.0, 1.0)
	if new_fill < _fill:
		_trail_delay = 0.35
	else:
		_trail = new_fill
	_fill = new_fill
	if _material != null:
		_material.set_shader_parameter("max_hp", float(_max))
		_material.set_shader_parameter("fill", _fill)
		_material.set_shader_parameter("trail", maxf(_trail, _fill))
	visible = not (hide_when_full and current >= maximum)


func set_level(level: int) -> void:
	if _level_label != null:
		_level_label.text = str(level)


func _process(delta: float) -> void:
	if _trail <= _fill or _material == null:
		return
	if _trail_delay > 0.0:
		_trail_delay -= delta
		return
	_trail = maxf(_fill, _trail - delta * 0.8)
	_material.set_shader_parameter("trail", _trail)


## Adds a bar above `owner_node` at `height_offset` and returns it.
static func attach(owner_node: Node3D, height_offset: float, bar_style: String, bar_width: float = 1.2) -> HealthBar3D:
	var bar: HealthBar3D = HealthBar3D.new()
	bar.style = bar_style
	bar.width = bar_width
	bar.position = Vector3(0, height_offset, 0)
	owner_node.add_child(bar)
	return bar
