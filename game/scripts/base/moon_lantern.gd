class_name MoonLantern
extends Node3D

## MoonLantern
##
## The old stone lantern by the tent (feature 036, docs/design/story.md).
## The kids rebuild it with Glow Shards, the pieces of the moon's light:
## stand next to it and press E to hand over the shards in the stash.
## Each stage lights a bigger safe ring around the camp (radius 4 -> 9 m):
## mobs inside are slowed, shadow creatures take light damage, and near
## the top stages Mushroom Gremlins turn back at its edge.
##
## Chapter 1 has 3 stages, Chapter 2 has 6 (`costs_chapter_*`, shards
## per stage). The model is the team's sheet built in Blender
## (feature 047, art/props/camp.py moon_lantern): the shards stack up
## inside its glass, the core glows and the carved crescent lights up.
##
## A saving system (run lifecycle 03): its shards go in the save file
## under "lantern" (saves from before feature 036 start it dark).

signal stage_changed(stage: int, max_stage: int)
signal shards_delivered(amount: int)

const GROUP: StringName = &"moon_lantern"
const SHARD_ID: StringName = &"glow_shards"

## Shards for each stage, per chapter. Tuned so a careful player lights
## the last stage on the last night (about 14 shards drop in Chapter 1
## and 65 in Chapter 2, see docs/history/features/036-moon-lantern).
@export var costs_chapter_1: PackedInt32Array = PackedInt32Array([2, 4, 5])
@export var costs_chapter_2: PackedInt32Array = PackedInt32Array([3, 5, 6, 8, 10, 12])
@export var min_radius: float = 4.0
@export var max_radius: float = 9.0
## Mob speed inside the ring (torches: 0.45).
@export var slow_factor: float = 0.7
@export var light_damage: int = 1
@export var light_interval_seconds: float = 1.5
## Gremlins turn back once the lantern is this far lit.
@export var ward_fraction: float = 0.8
@export var interact_radius: float = 2.4

## Shards handed over so far this run.
var shards: int = 0
var stage: int = 0

const MODEL: PackedScene = preload("res://assets/custom/moon_lantern.glb")
## The lamp housing in the model (between its iron rails), and the carved
## crescent on the plinth's front.
const HOUSING_Y: float = 1.27
const HOUSING_HALF: float = 0.19
const CRESCENT_POS: Vector3 = Vector3(0.0, 0.53, 0.262)

var _orb_material: StandardMaterial3D = null
var _crescent_material: StandardMaterial3D = null
var _crystals: Array[MeshInstance3D] = []
var _crystal_lit: StandardMaterial3D = null
var _crystal_dull: StandardMaterial3D = null
var _light: OmniLight3D = null
var _ring: MeshInstance3D = null
var _ring_mesh: TorusMesh = null
var _prompt: Label3D = null
var _tick: float = 0.0


static func find(tree: SceneTree) -> MoonLantern:
	return tree.get_first_node_in_group(GROUP) as MoonLantern if tree != null else null


func _ready() -> void:
	add_to_group(GROUP)
	_build_model()
	_refresh(false)


func costs() -> PackedInt32Array:
	return costs_chapter_2 if GameManager.chapter() == 2 else costs_chapter_1


func max_stage() -> int:
	return costs().size()


## The stage `delivered` shards reach.
func stage_for(delivered: int) -> int:
	var total: int = 0
	var reached: int = 0
	for cost in costs():
		total += cost
		if delivered < total:
			break
		reached += 1
	return reached


func shards_for_max() -> int:
	var total: int = 0
	for cost in costs():
		total += cost
	return total


## Shards still needed for the next stage (0 when fully lit).
func shards_to_next() -> int:
	if stage >= max_stage():
		return 0
	var total: int = 0
	for i in range(stage + 1):
		total += costs()[i]
	return total - shards


func is_full() -> bool:
	return stage >= max_stage()


func radius() -> float:
	if stage <= 0:
		return 0.0
	if max_stage() <= 1:
		return max_radius
	return lerpf(min_radius, max_radius, float(stage - 1) / float(max_stage() - 1))


## Inside the lit ring (the torch-style slow uses this).
func affects(point: Vector3) -> bool:
	var offset: Vector3 = point - global_position
	offset.y = 0.0
	return stage > 0 and offset.length() <= radius()


## Gremlins turn back here once the lantern is bright enough.
func wards(point: Vector3) -> bool:
	return affects(point) and float(stage) / float(max_stage()) >= ward_fraction - 0.001


func in_reach(point: Vector3) -> bool:
	var offset: Vector3 = point - global_position
	offset.y = 0.0
	return offset.length() <= interact_radius


func can_accept() -> bool:
	return not is_full() and ResourceManager.get_count(SHARD_ID) > 0


## Hands over the stash's shards (no more than the lantern still
## needs). Returns how many went in.
func deliver(from: Node3D = null) -> int:
	if not can_accept():
		return 0
	var amount: int = mini(ResourceManager.get_count(SHARD_ID), shards_for_max() - shards)
	if not ResourceManager.spend(SHARD_ID, amount):
		return 0
	shards += amount
	GameManager.record(&"lantern_shards", amount)
	PlaytestLog.write("lantern_fed amount=%d shards=%d day=%d" % [amount, shards, TimeManager.day_number])
	if from != null:
		var definition: ResourceDefinition = ResourceManager.get_definition(SHARD_ID)
		Fx.icon_popup(from, definition.icon if definition != null else null, "-%d" % amount, UiKit.COLOR_MOON)
	Fx.burst(&"shard", global_position + Vector3(0, 1.6, 0))
	shards_delivered.emit(amount)
	_refresh(true)
	return amount


## Rebuilds the lantern from a save without any fanfare.
func restore(delivered: int) -> void:
	shards = clampi(delivered, 0, shards_for_max())
	_refresh(false)


## {"lantern": {"shards"}} for the save file.
func save_state() -> Dictionary:
	return {"lantern": {"shards": shards}}


## Lights the lantern to the saved shards, without any fanfare.
func load_state(data: Dictionary) -> void:
	var saved: Variant = data.get("lantern", {})
	restore(int((saved as Dictionary).get("shards", 0)) if saved is Dictionary else 0)


## A fresh run's lantern: dark.
func reset() -> void:
	restore(0)


## Loses `count` stages of light (the Moon-Eater swallowed them,
## feature 038). Returns how many it lost.
func lose_stages(count: int) -> int:
	var keep: int = maxi(0, stage - count)
	var lost: int = stage - keep
	var total: int = 0
	for i in keep:
		total += costs()[i]
	shards = total
	_refresh(false)
	if lost > 0:
		PlaytestLog.write("lantern_swallowed stages=%d stage=%d" % [lost, stage])
	return lost


## Dims the lantern while the Moon-Eater drinks its light (0 = full
## glow, 1 = nearly dark).
func set_drain(fraction: float) -> void:
	var glow: float = float(stage) / float(maxi(1, max_stage())) * (1.0 - 0.85 * clampf(fraction, 0.0, 1.0))
	_set_glow(glow, 0.2 + glow * 1.3)


## The core, the crescent and the light follow how lit it is (0..1).
func _set_glow(glow: float, light_energy: float) -> void:
	_orb_material.emission_energy_multiplier = 0.15 + glow * 1.1
	_orb_material.albedo_color.a = 0.25 + glow * 0.6
	# The crescent wakes in the second half and blazes at the top stage.
	var crescent: float = clampf((glow - 0.3) / 0.7, 0.0, 1.0)
	_crescent_material.albedo_color.a = crescent
	_crescent_material.emission_energy_multiplier = 0.4 + crescent * 1.6
	_light.light_energy = 0.0 if stage == 0 else light_energy


## For the dawn card: what the lantern needs next.
func hint_text() -> String:
	if is_full():
		return "The Moon Lantern shines bright!"
	var need: int = shards_to_next()
	return "Bring %d more Glow Shard%s to the Moon Lantern (E)." % [need, "" if need == 1 else "s"]


func _physics_process(delta: float) -> void:
	_update_prompt()
	if stage <= 0:
		return
	_tick += delta
	if _tick < light_interval_seconds:
		return
	_tick = 0.0
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob: Mob = node as Mob
		if mob != null and mob.definition != null and mob.definition.hurt_by_moonlight and affects(mob.global_position):
			mob.take_damage(light_damage, null)


func _update_prompt() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	_prompt.visible = player != null and in_reach(player.global_position) and can_accept()


func _refresh(announce: bool) -> void:
	var old: int = stage
	stage = stage_for(shards)
	var top: int = max_stage()
	var glow: float = float(stage) / float(maxi(1, top))
	_set_glow(glow, 0.5 + glow * 1.0)
	_light.omni_range = 2.0 + radius() * 0.6
	for i in _crystals.size():
		_crystals[i].material_override = _crystal_lit if i < stage else _crystal_dull
	_ring.visible = stage > 0
	if stage > 0:
		_ring_mesh.inner_radius = radius() - 0.1
		_ring_mesh.outer_radius = radius() + 0.1
	if stage != old:
		stage_changed.emit(stage, top)
		if announce:
			Fx.burst(&"level_up", global_position)
			Fx.float_text(self, "MOON LANTERN %d/%d" % [stage, top], UiKit.COLOR_MOON.lightened(0.4), 2.8)
			PlaytestLog.write("lantern_stage stage=%d of %d day=%d" % [stage, top, TimeManager.day_number])


# --- Model -------------------------------------------------------------------

func _build_model() -> void:
	var visual: Node3D = MODEL.instantiate()
	visual.name = "Visual"
	add_child(visual)
	Stylize.apply(visual, "prop")

	# Faint glass in the iron frame, so the shards inside show.
	var glass_material: StandardMaterial3D = StandardMaterial3D.new()
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.albedo_color = Color(0.72, 0.82, 0.95, 0.16)
	glass_material.metallic_specular = 0.9
	glass_material.roughness = 0.15
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var pane: BoxMesh = BoxMesh.new()
	pane.size = Vector3(HOUSING_HALF * 2.0, 0.44, HOUSING_HALF * 2.0)
	pane.material = glass_material
	var glass: MeshInstance3D = _part(self, pane, glass_material, HOUSING_Y)
	glass.name = "Glass"
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.set_meta(&"stylized", "skip")

	# The moonlight core, and one shard per stage standing round it on
	# the lamp's floor; these glow, so they stay out of the painted look.
	_orb_material = StandardMaterial3D.new()
	_orb_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_orb_material.albedo_color = Color(0.7, 0.78, 1.0, 0.3)
	_orb_material.emission_enabled = true
	_orb_material.emission = UiKit.COLOR_MOON
	var orb: SphereMesh = SphereMesh.new()
	orb.radius = 0.09
	orb.height = 0.18
	var core: MeshInstance3D = _part(self, orb, _orb_material, HOUSING_Y + 0.02)
	core.set_meta(&"stylized", "skip")
	_crystal_lit = StandardMaterial3D.new()
	_crystal_lit.albedo_color = Color(0.75, 0.95, 1.0)
	_crystal_lit.emission_enabled = true
	_crystal_lit.emission = Color(0.55, 0.85, 1.0)
	_crystal_lit.emission_energy_multiplier = 1.4
	_crystal_dull = _material(Color(0.32, 0.34, 0.45))
	for i in max_stage():
		var angle: float = TAU * i / float(max_stage()) + 0.3
		var prism: PrismMesh = PrismMesh.new()
		prism.size = Vector3(0.06, 0.16 + 0.04 * float(i % 2), 0.06)
		var crystal: MeshInstance3D = _part(self, prism, _crystal_dull, HOUSING_Y - 0.13)
		crystal.position.x = cos(angle) * 0.11
		crystal.position.z = sin(angle) * 0.11
		crystal.rotation = Vector3(sin(angle) * 0.25, angle, -cos(angle) * 0.25)
		crystal.set_meta(&"stylized", "skip")
		_crystals.append(crystal)

	# The carved crescent's glow: a moon-shaped decal just off the stone.
	_crescent_material = StandardMaterial3D.new()
	_crescent_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_crescent_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_crescent_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_crescent_material.albedo_texture = _crescent_texture()
	_crescent_material.albedo_color = Color(1.0, 0.9, 0.62, 0.0)
	_crescent_material.emission_enabled = true
	_crescent_material.emission = Color(1.0, 0.85, 0.5)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var decal: MeshInstance3D = _part(self, quad, _crescent_material, CRESCENT_POS.y)
	decal.name = "CrescentGlow"
	decal.position.z = CRESCENT_POS.z
	decal.rotation.x = -0.077  # leans back with the plinth's taper
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decal.set_meta(&"stylized", "skip")

	_light = OmniLight3D.new()
	_light.light_color = Color(0.7, 0.8, 1.0)
	_light.position = Vector3(0, HOUSING_Y, 0)
	_light.shadow_enabled = false
	add_child(_light)

	_ring_mesh = TorusMesh.new()
	_ring_mesh.rings = 96
	_ring_mesh.ring_segments = 6
	var ring_material: StandardMaterial3D = StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_material.albedo_color = Color(0.55, 0.7, 1.0, 0.45)
	_ring = MeshInstance3D.new()
	_ring.name = "LightRing"
	_ring.mesh = _ring_mesh
	_ring.material_override = ring_material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.scale = Vector3(1.0, 0.04, 1.0)
	_ring.position.y = 0.04
	add_child(_ring)

	_prompt = Label3D.new()
	_prompt.text = "E  Moon Lantern"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.font_size = 40
	_prompt.outline_size = 10
	_prompt.modulate = UiKit.COLOR_MOON.lightened(0.5)
	_prompt.position = Vector3(0, 2.4, 0)
	_prompt.visible = false
	add_child(_prompt)


## A soft crescent moon (the carving's shape) for the glow decal: a disc
## with a smaller disc bitten out of its right side, feathered.
static func _crescent_texture() -> ImageTexture:
	var size: int = 64
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) / float(size) * 2.0 - Vector2.ONE
			p /= 0.82  # the carving fills most of the quad, with room to glow
			var outer: float = 1.0 - p.length()
			var bite: float = (p - Vector2(0.56, 0.0)).length() - 0.74
			var inside: float = minf(outer, bite)
			image.set_pixel(x, y, Color(1, 1, 1, clampf(inside * 8.0 + 0.5, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


## Named like the painted assets, so Stylize gives it the same painted
## shading and ink line as the 031 props.
func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.resource_name = "lantern" + Stylize.PAINTED_SUFFIX
	return material


## On the mesh itself (not an override), so Stylize can paint it.
func _part(parent: Node3D, mesh: PrimitiveMesh, material: Material, y: float) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	mesh.material = material
	instance.mesh = mesh
	instance.position.y = y
	parent.add_child(instance)
	return instance
