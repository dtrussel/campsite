extends "res://scripts/ui/title_backdrop.gd"

## HeroStage
##
## 3D backdrop of the hero select screen: the dusk camp
## from the title screen, with every hero of the roster standing in a
## row in front of the fire, idling and fidgeting now and then. The
## picked hero cheers and stands in an ember ring of light; the camera
## drifts a little toward them.

const SPACING: float = 1.8
const ROW_Z: float = 2.6
const RING_COLOR: Color = Color(1.0, 0.62, 0.25)

var _visuals: Array[CharacterVisual] = []
var _ring: MeshInstance3D = null
var _glow: OmniLight3D = null
var _selected: int = 0
var _focus_x: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	seat_heroes = false
	super._ready()
	_clear_foreground()
	var heroes: Array[HeroDefinition] = HeroRoster.all()
	for i in heroes.size():
		var hero: HeroDefinition = heroes[i]
		var visual: CharacterVisual = CharacterVisual.new()
		visual.model_scene = hero.model_scene
		visual.model_scale = hero.model_scale
		visual.clips = hero.clips.duplicate()
		visual.fidgets = hero.fidgets.duplicate()
		visual.spring_chains = hero.spring_chains.duplicate()
		visual.face_atlas = hero.face_atlas
		visual.style = "hero"
		visual.outfit_mesh = hero.outfit_mesh
		visual.outfit_tint = Cosmetics.outfit_tint(hero.id)
		visual.lean = false
		visual.position = Vector3(_slot_x(i, heroes.size()), 0, ROW_Z)
		add_child(visual)
		visual.face_instantly(Vector3(0, 0, 1))
		_visuals.append(visual)

	_ring = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.48
	torus.outer_radius = 0.6
	torus.rings = 32
	torus.ring_segments = 6
	_ring.mesh = torus
	_ring.scale = Vector3(1, 0.15, 1)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = RING_COLOR
	material.emission_enabled = true
	material.emission = RING_COLOR
	material.emission_energy_multiplier = 2.0
	_ring.material_override = material
	_ring.set_meta(&"stylized", "skip")
	add_child(_ring)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.75, 0.45)
	_glow.light_energy = 1.6
	_glow.omni_range = 3.0
	add_child(_glow)
	select(0, false)


## Highlights hero `index`; `cheer` plays their cheer.
func select(index: int, cheer: bool = true) -> void:
	if _visuals.is_empty():
		return
	_selected = clampi(index, 0, _visuals.size() - 1)
	var spot: Vector3 = _visuals[_selected].position
	_ring.position = spot + Vector3(0, 0.03, 0)
	_glow.position = spot + Vector3(0, 1.4, 0.9)
	if cheer:
		_visuals[_selected].play_action(&"cheer", 1.0)


## Dresses hero `index` in outfit `color` (hero select's outfit row).
func set_outfit_tint(index: int, color: Color) -> void:
	if index >= 0 and index < _visuals.size():
		_visuals[index].set_outfit_tint(color)


## Recolours the camp tent behind the heroes (hero select's outfit row).
func set_tent_tint(color: Color) -> void:
	for tent in get_tree().get_nodes_in_group(&"tent"):
		if is_ancestor_of(tent):
			tent.set_meta(Stylize.TINT_META, color)
			Stylize.apply(tent, "prop")


func _process(delta: float) -> void:
	_time += delta
	if _ring != null:
		_ring.rotation.y += delta * 0.6
		(_ring.material_override as StandardMaterial3D).emission_energy_multiplier = 1.7 + sin(_time * 3.0) * 0.4
	super._process(delta)


## A fixed, low front view that drifts toward the picked hero.
func _update_camera(delta: float) -> void:
	if _camera == null:
		return
	var target_x: float = _visuals[_selected].position.x * 0.35 if not _visuals.is_empty() else 0.0
	_focus_x = lerpf(_focus_x, target_x, clampf(delta * 3.0, 0.0, 1.0)) if delta > 0.0 else target_x
	_camera.fov = 36.0
	_camera.position = Vector3(_focus_x + sin(_time * 0.3) * 0.12, 2.1, ROW_Z + 6.0)
	_camera.look_at(Vector3(_focus_x, 0.15, ROW_Z - 0.8))


## Hides camp dressing between the camera and the heroes (the yard's
## lantern posts and crates would stand in front of them).
func _clear_foreground() -> void:
	for child in get_children():
		if not child.get_script() or not String(child.get_script().resource_path).ends_with("world_dressing.gd"):
			continue
		for prop in child.get_children():
			var node: Node3D = prop as Node3D
			if node != null and node.position.z > ROW_Z + 0.8 and absf(node.position.x) < 7.0:
				node.visible = false
				if node is CollisionObject3D:
					node.process_mode = Node.PROCESS_MODE_DISABLED


func _slot_x(index: int, count: int) -> float:
	return (float(index) - float(count - 1) * 0.5) * SPACING
