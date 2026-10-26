class_name CharacterFace
extends RefCounted

## CharacterFace
##
## A character visual's painted face (CharacterVisual composes one when
## it has a face atlas). The head's face surface shows one cell of its
## FaceAtlas (painted_face.gdshader): the neutral face, blinking now and
## then (BlinkScheduler), or an expression for as long as a hit or a
## cheer plays, and dazed while down (play_final). The visual stops
## ticking it through a hit-stop, so the face holds with the pose.

const SHADER: Shader = preload("res://shaders/painted_face.gdshader")
## Action state -> the expression it shows while it plays.
const EXPRESSIONS: Dictionary = {&"hit": &"hurt", &"cheer": &"happy"}
## The expression while down.
const DOWN: StringName = &"dazed"

## Blinks shown so far (tests).
var blinks_shown: int = 0

var _atlas: FaceAtlas = null
var _material: ShaderMaterial = null
var _blinks: BlinkScheduler = BlinkScheduler.new()
var _shown: StringName = &""


## Puts `atlas`'s face on `model`'s head, or null when the head has no
## face surface for it.
static func attach(model: Node3D, atlas: FaceAtlas) -> CharacterFace:
	var head: MeshInstance3D = model.find_child(atlas.mesh, true, false) as MeshInstance3D
	if head == null or head.mesh == null:
		return null
	for surface in head.mesh.get_surface_count():
		var source: Material = head.mesh.surface_get_material(surface)
		if source == null or source.resource_name != atlas.material:
			continue
		var face: CharacterFace = CharacterFace.new()
		face._atlas = atlas
		face._material = _face_material(head, surface, source, atlas)
		head.set_surface_override_material(surface, face._material)
		face._show(FaceAtlas.NEUTRAL)
		return face
	return null


static func _face_material(head: MeshInstance3D, surface: int, source: Material, atlas: FaceAtlas) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	var styled: ShaderMaterial = head.get_surface_override_material(surface) as ShaderMaterial
	if styled != null:
		# The head's own painted look (Stylize) and its ink line.
		for uniform in styled.shader.get_shader_uniform_list():
			var key: StringName = StringName(uniform["name"])
			material.set_shader_parameter(key, styled.get_shader_parameter(key))
		material.next_pass = styled.next_pass
	elif source is BaseMaterial3D:
		material.set_shader_parameter("albedo_texture", (source as BaseMaterial3D).albedo_texture)
	material.set_shader_parameter("face_atlas", atlas.texture)
	var window: Rect2 = atlas.window
	material.set_shader_parameter("face_window", Vector4(window.position.x, window.position.y,
		window.size.x, window.size.y))
	material.set_shader_parameter("cell_size", atlas.cell_size)
	return material


## The face state the head shows now (&"open", &"closed", &"hurt", ...),
## read back from its material (tests).
func shown() -> StringName:
	var origin: Vector2 = _material.get_shader_parameter("cell_origin")
	for i in _atlas.states.size():
		if _atlas.cell_origins[i].is_equal_approx(origin):
			return StringName(_atlas.states[i])
	return &""


## Picks this frame's face: the expression of `action` (the action
## playing, or &"") or of being `down`, else neutral with its blinks.
func tick(delta: float, action: StringName, down: bool) -> void:
	var state: StringName = DOWN if down else EXPRESSIONS.get(action, FaceAtlas.NEUTRAL)
	if not _atlas.has_state(state):
		state = FaceAtlas.NEUTRAL
	var shut: bool = _blinks.tick(delta)
	if state == FaceAtlas.NEUTRAL and shut:
		state = FaceAtlas.BLINK
		if _shown != FaceAtlas.BLINK:
			blinks_shown += 1
	_show(state)


func _show(state: StringName) -> void:
	if state == _shown:
		return
	_shown = state
	_material.set_shader_parameter("cell_origin", _atlas.cell_origin(state))
