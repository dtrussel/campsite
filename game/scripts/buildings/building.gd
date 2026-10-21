class_name Building
extends StaticBody3D

## Building
##
## Shared behaviour for any placed building (Wooden Fence, Watch Post,
## ...). Holds a BuildingDefinition and current HP. Phase 3 ships only
## the public surface (take_damage / repair / destroyed) so Phase 5
## (mobs) and Phase 4 (companion repair) can wire in without touching
## any building scene.
##
## Playtest 1 (feature 044): construction. BuildManager places a
## building as a *blueprint* (start_as_blueprint() before it enters the
## tree): a see-through blue ghost of the finished shape on a staked-out
## site with a pile of materials (feature 045), and a progress bar. It
## does nothing yet. The hero (and the companion on its Repair task)
## walks over and hammers it up with add_build_progress(): the solid
## building rises inside the ghost from the bottom up while the pile
## shrinks, and complete_construction() then switches it on with a pop.
## Subclasses switch themselves on in _on_built(), not _ready().
##
## Saving (run lifecycle 03): save_entry() is a building's line in the
## save file and rebuild() puts one back, with the legacy fallbacks;
## BuildingSaves lists them for the run session.

## Every placed building (not build-mode ghosts); the autosave lists them.
const BUILDINGS_GROUP: StringName = &"buildings"
## Buildings still waiting to be built, oldest first.
const BLUEPRINT_GROUP: StringName = &"blueprints"
## Share of the building's height already solid on a fresh blueprint.
const BLUEPRINT_START_HEIGHT: float = 0.04
const GHOST_SHADER: Shader = preload("res://shaders/blueprint_ghost.gdshader")
const BUILD_SHADER: Shader = preload("res://shaders/painted_prop_build.gdshader")
## Site props: stake and rope colours, and the pile piece per cost item.
const STAKE_COLOR: Color = Color(0.55, 0.36, 0.2)
const ROPE_COLOR: Color = Color(0.9, 0.8, 0.58)
const PILE_PIECES: Dictionary = {
	&"wood": [Vector3(0.6, 0.07, 0.13), Color(0.74, 0.5, 0.28)],
	&"stone": [Vector3(0.17, 0.12, 0.15), Color(0.6, 0.6, 0.62)],
	&"clay": [Vector3(0.2, 0.08, 0.11), Color(0.72, 0.4, 0.26)],
	&"scrap": [Vector3(0.18, 0.05, 0.14), Color(0.45, 0.47, 0.52)],
	&"glow_shard": [Vector3(0.08, 0.16, 0.08), Color(0.45, 0.95, 1.0)],
}
const MAX_PILE_PIECES: int = 7
## Share of max HP a fresh blueprint has; the rest comes as it is built.
const BLUEPRINT_START_HP: float = 0.2

signal damaged(new_hp: int)
signal repaired(new_hp: int)
signal destroyed
signal construction_finished

@export var definition: BuildingDefinition

## Height of the overhead HP label; set per scene.
@export var hp_label_height: float = 1.6
## Hammer taps (Repair) restore this much HP each; 0 = not repairable
## (traps are rebuilt, not repaired).
@export var repair_per_tap: int = 12
## Optional defensive behaviour (Watch Post): damage the nearest mob in
## range every interval. 0 damage disables it.
@export var auto_attack_damage: int = 0
@export var auto_attack_range: float = 5.0
@export var auto_attack_interval: float = 1.5

var _auto_attack_timer: float = 0.0

var current_hp: int = 0
var _hp_bar: HealthBar3D = null
## 0..1 while a blueprint, 1 once built.
var build_progress: float = 1.0
var _construction_damage: int = 0
var _build_bar: HealthBar3D = null
## Blueprint dressing (feature 045): the ghost copy of Visual, the
## staked site with its material pile, and Visual's cut-off materials.
var _ghost: Node3D = null
var _ghost_material: ShaderMaterial = null
var _site: Node3D = null
var _pile: Array[Node3D] = []
var _build_materials: Array[ShaderMaterial] = []
var _restore_materials: Array = []  # [mesh, surface, material]
## Visual's height span in the building's own space.
var _model_bottom: float = 0.0
var _model_top: float = 1.0
## Direct children switched off while a blueprint (lights, auras, rings).
var _parked: Array[Node3D] = []
## Set by start_as_blueprint() before the building enters the tree.
var _starts_as_blueprint: bool = false
var _start_progress: float = 0.0
## What was paid for the blueprint (refunded when it is taken back), if
## that is known.
var _paid_cost: Dictionary = {}
var _has_paid_cost: bool = false


func _ready() -> void:
	if definition != null:
		current_hp = definition.max_hp
	else:
		push_warning("Building '%s' has no definition" % name)
	# The build-mode ghost is a real instance; keep it inert.
	set_physics_process(false)
	if has_meta(&"build_ghost"):
		return
	add_to_group(BUILDINGS_GROUP)
	_hp_bar = HealthBar3D.attach(self, hp_label_height, "structure", 1.1)
	_hp_bar.hide_when_full = true
	_refresh_hp_label.call_deferred()
	if _starts_as_blueprint:
		_enter_blueprint(_start_progress)
	else:
		_on_built()


## Makes the building start as a blueprint `progress` (0..1) built, paid
## for with `paid` (a cost Dictionary; null when unknown, and a refund
## then falls back to BuildManager.cost_of). Call before it enters the
## tree.
func start_as_blueprint(progress: float = 0.0, paid: Variant = null) -> void:
	_starts_as_blueprint = true
	_start_progress = progress
	_has_paid_cost = paid is Dictionary
	_paid_cost = (paid as Dictionary).duplicate() if paid is Dictionary else {}


## Whether the blueprint knows what was paid for it.
func has_paid_cost() -> bool:
	return _has_paid_cost


## What was paid for the blueprint ({} when unknown: see has_paid_cost).
func paid_cost() -> Dictionary:
	return _paid_cost.duplicate()


## The HP bar over the building (null for a build-mode ghost).
func health_bar() -> HealthBar3D:
	return _hp_bar


## The building's line in the save file: id, place, HP and construction
## progress, and what a blueprint was paid with (when known).
func save_entry() -> Dictionary:
	var p: Vector3 = global_position
	var entry: Dictionary = {
		"id": String(definition.id),
		"pos": [p.x, p.y, p.z],
		"yaw": global_rotation.y,
		"hp": current_hp,
		"progress": build_progress,
	}
	if is_blueprint() and _has_paid_cost:
		var paid: Dictionary = {}
		for id in _paid_cost.keys():
			paid[String(id)] = int(_paid_cost[id])
		entry["paid"] = paid
	return entry


## Puts back the building `entry` (from save_entry) under `parent`, or
## null when its type is gone. A blueprint gets its progress again (its
## HP follows from it); saves from before perk cards have no "paid", so
## its refund falls back to BuildManager.cost_of.
static func rebuild(entry: Dictionary, parent: Node) -> Building:
	var definition: BuildingDefinition = BuildManager.get_definition(StringName(str(entry.get("id", ""))))
	if definition == null or definition.get_scene() == null:
		return null
	var building: Building = definition.get_scene().instantiate() as Building
	var progress: float = float(entry.get("progress", 1.0))
	if progress < 1.0:
		var paid: Variant = null
		if entry.get("paid") is Dictionary:
			var cost: Dictionary = {}
			for id in (entry["paid"] as Dictionary).keys():
				cost[StringName(id)] = int(entry["paid"][id])
			paid = cost
		building.start_as_blueprint(progress, paid)
	parent.add_child(building)
	var pos: Array = entry["pos"]
	building.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	building.global_rotation.y = float(entry.get("yaw", 0.0))
	if progress >= 1.0:
		building.current_hp = clampi(int(entry.get("hp", definition.max_hp)), 1, definition.max_hp)
		building._refresh_hp_label()
	return building


## Switches the building on (also right away for a building that was
## never a blueprint). Subclasses call super() and add their groups.
func _on_built() -> void:
	if repair_per_tap > 0:
		add_to_group(Repair.GROUP)
	set_physics_process(auto_attack_damage > 0)


func is_built() -> bool:
	return build_progress >= 1.0


func is_blueprint() -> bool:
	return build_progress < 1.0


## Seconds of hammering it takes from blueprint to building.
func build_seconds() -> float:
	return maxf(definition.build_seconds if definition != null else 2.0, 0.1)


## Hammering: `seconds` of work by `builder`. True once it is finished.
func add_build_progress(seconds: float, builder: Node = null) -> bool:
	if is_built() or current_hp <= 0:
		return is_built()
	build_progress = minf(1.0, build_progress + seconds / build_seconds())
	_refresh_construction()
	if build_progress >= 1.0:
		complete_construction(builder)
	return is_built()


## Finishes a blueprint at once (the builder gets the build XP).
func complete_construction(builder: Node = null) -> void:
	if not _starts_as_blueprint and _parked.is_empty() and is_built():
		return
	build_progress = 1.0
	_starts_as_blueprint = false
	remove_from_group(BLUEPRINT_GROUP)
	current_hp = maxi(1, get_max_hp() - _construction_damage)
	_construction_damage = 0
	_undress_blueprint()
	for child in _parked:
		if is_instance_valid(child):
			child.visible = true
			child.process_mode = Node.PROCESS_MODE_INHERIT
	_parked.clear()
	if _build_bar != null:
		_build_bar.queue_free()
		_build_bar = null
	_refresh_hp_label()
	_on_built()
	Fx.burst(&"build", global_position + Vector3(0, 0.4, 0))
	Fx.burst(&"build_done", global_position + Vector3(0, _model_top * 0.6, 0))
	Fx.shake(0.05)
	if definition != null:
		AudioManager.play_sfx(definition.place_sound, global_position)
	BuildManager.on_construction_finished(self, builder)
	construction_finished.emit()


func _enter_blueprint(progress: float) -> void:
	build_progress = clampf(progress, 0.0, 0.999)
	add_to_group(BLUEPRINT_GROUP)
	for child in get_children():
		var node: Node3D = child as Node3D
		if node == null or node.name == &"Visual" or child is CollisionShape3D:
			continue
		if node.visible or node.process_mode != Node.PROCESS_MODE_DISABLED:
			node.visible = false
			node.process_mode = Node.PROCESS_MODE_DISABLED
			_parked.append(node)
	_build_bar = HealthBar3D.attach(self, hp_label_height + 0.3, "build", 0.9)
	_dress_blueprint()
	_refresh_construction()
	# BuildManager and the save loader move the building after _ready.
	_refresh_construction.call_deferred()


## The ghost, the cut-off solid materials and the site (feature 045).
func _dress_blueprint() -> void:
	var visual: Node3D = get_node_or_null("Visual") as Node3D
	if visual == null:
		return
	# Style now (not a frame later via StyleDirector) so the painted
	# materials exist to copy.
	Stylize.apply(visual, "prop")
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(visual, meshes)
	var to_local: Transform3D = global_transform.affine_inverse()
	var span: AABB = AABB()
	for i in range(meshes.size()):
		var box: AABB = (to_local * meshes[i].global_transform) * meshes[i].get_aabb()
		span = box if i == 0 else span.merge(box)
	_model_bottom = span.position.y
	_model_top = maxf(span.end.y, _model_bottom + 0.1)

	_ghost = visual.duplicate() as Node3D
	_ghost.name = &"Ghost"
	_ghost_material = ShaderMaterial.new()
	_ghost_material.shader = GHOST_SHADER
	_ghost_material.set_shader_parameter("fade", 1.0)
	_ghost_material.set_shader_parameter("hit_flash", 0.0)
	var ghost_meshes: Array[MeshInstance3D] = []
	_collect_meshes(_ghost, ghost_meshes)
	for mesh in ghost_meshes:
		mesh.set_meta(&"stylized", "skip")
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in range(mesh.mesh.get_surface_count()):
			mesh.set_surface_override_material(surface, _ghost_material)
	add_child(_ghost)

	for mesh in meshes:
		for surface in range(mesh.mesh.get_surface_count()):
			var painted: ShaderMaterial = mesh.get_surface_override_material(surface) as ShaderMaterial
			if painted == null or painted.shader != Stylize.PAINTED_SHADER:
				continue
			var cut: ShaderMaterial = ShaderMaterial.new()
			cut.shader = BUILD_SHADER
			for uniform in Stylize.PAINTED_SHADER.get_shader_uniform_list():
				var value: Variant = painted.get_shader_parameter(uniform["name"])
				if value != null:
					cut.set_shader_parameter(uniform["name"], value)
			_restore_materials.append([mesh, surface, painted])
			_build_materials.append(cut)
			mesh.set_surface_override_material(surface, cut)

	_site = _make_site()
	add_child(_site)


static func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)


## Corner stakes with a rope line, a dirt patch, and a pile of what the
## building costs (planks, stones, ...) that shrinks as it is built.
func _make_site() -> Node3D:
	var size: Vector3 = definition.footprint_size if definition != null else Vector3.ONE
	var half: Vector2 = Vector2(size.x * 0.5 + 0.25, size.z * 0.5 + 0.25)
	var site: Node3D = Node3D.new()
	site.name = &"Site"
	var patch: MeshInstance3D = _site_box(Vector3(half.x * 2.0, 0.01, half.y * 2.0), Color(0.55, 0.42, 0.28, 0.3))
	patch.position.y = 0.02
	patch.set_meta(&"stylized", "skip")
	site.add_child(patch)
	var corners: Array[Vector3] = [Vector3(-half.x, 0, -half.y), Vector3(half.x, 0, -half.y),
		Vector3(half.x, 0, half.y), Vector3(-half.x, 0, half.y)]
	for i in range(4):
		var stake: MeshInstance3D = _site_box(Vector3(0.08, 0.5, 0.08), STAKE_COLOR)
		stake.position = corners[i] + Vector3(0, 0.25, 0)
		stake.rotation = Vector3(0.08 * signf(corners[i].z), 0.4, -0.08 * signf(corners[i].x))
		site.add_child(stake)
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var rope: MeshInstance3D = _site_box(Vector3(a.distance_to(b), 0.025, 0.025), ROPE_COLOR)
		rope.position = (a + b) * 0.5 + Vector3(0, 0.4, 0)
		rope.rotation.y = -atan2(b.z - a.z, b.x - a.x)
		site.add_child(rope)
	# The pile sits just outside the front-right corner.
	var anchor: Vector3 = Vector3(half.x + 0.35, 0, half.y - 0.1)
	var count: int = 0
	var cost: Dictionary = definition.cost if definition != null else {&"wood": 3}
	for id in cost.keys():
		var piece: Array = PILE_PIECES.get(StringName(id), PILE_PIECES[&"wood"])
		for k in range(clampi(int(cost[id]), 1, 3 if StringName(id) != &"wood" else 4)):
			if count >= MAX_PILE_PIECES:
				break
			var part: MeshInstance3D = _site_box(piece[0], piece[1])
			var layer: int = count / 2
			var side: float = -0.08 if count % 2 == 0 else 0.08
			part.position = anchor + Vector3(side if layer % 2 == 0 else 0.0, 0.0, 0.0 if layer % 2 == 0 else side)
			part.position.y = (piece[0] as Vector3).y * 0.5 + layer * 0.075
			part.rotation.y = (PI * 0.5 if layer % 2 == 1 else 0.0) + 0.1 * float((count * 7) % 3 - 1)
			site.add_child(part)
			_pile.append(part)
			count += 1
	for child in site.get_children():
		if child != patch:
			Stylize.apply_mesh(child as MeshInstance3D, "prop")
	return site


func _site_box(box_size: Vector3, color: Color) -> MeshInstance3D:
	var box: BoxMesh = BoxMesh.new()
	box.size = box_size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = material
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = box
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


## Feature 045: the finish. The ghost fades, the site sinks away, the
## solid building gets its own materials back and bounces.
func _undress_blueprint() -> void:
	for entry in _restore_materials:
		if is_instance_valid(entry[0]):
			(entry[0] as MeshInstance3D).set_surface_override_material(entry[1], entry[2])
	_restore_materials.clear()
	_build_materials.clear()
	_pile.clear()
	var tween: Tween = create_tween().set_parallel(true)
	if _ghost != null:
		tween.tween_property(_ghost_material, "shader_parameter/fade", 0.0, 0.25)
		tween.tween_property(_ghost, "scale", Vector3.ONE * 1.08, 0.25)
		tween.chain().tween_callback(_ghost.queue_free)
		_ghost = null
	if _site != null:
		var site: Node3D = _site
		var sink: Tween = create_tween()
		sink.tween_property(site, "position:y", -0.6, 0.25).set_ease(Tween.EASE_IN)
		sink.tween_callback(site.queue_free)
		_site = null
	var visual: Node3D = get_node_or_null("Visual") as Node3D
	if visual != null:
		var pop: Tween = create_tween()
		pop.tween_property(visual, "scale", Vector3(1.1, 1.12, 1.1), 0.12).set_ease(Tween.EASE_OUT)
		pop.tween_property(visual, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A builder's hammer lands (BuildBeat, feature 045): a squash on the
## solid part, a flash on the ghost, and chips (with their knock).
func on_build_hit() -> void:
	if not is_inside_tree():
		return
	var visual: Node3D = get_node_or_null("Visual") as Node3D
	if visual != null:
		visual.scale = Vector3(1.03, 0.95, 1.03)
		create_tween().tween_property(visual, "scale", Vector3.ONE, 0.14).set_ease(Tween.EASE_OUT)
	if _ghost_material != null and is_blueprint():
		_ghost_material.set_shader_parameter("hit_flash", 1.0)
		create_tween().tween_property(_ghost_material, "shader_parameter/hit_flash", 0.0, 0.3)
	Fx.burst(&"wood", global_position + Vector3(0, build_line_height() + 0.05, 0))


## World height of the build line above the building's origin.
func build_line_height() -> float:
	return lerpf(_model_bottom, _model_top, lerpf(BLUEPRINT_START_HEIGHT, 1.0, build_progress)) \
		if is_blueprint() else _model_top


## Flat distance from `point` to the edge of the footprint (0 inside).
func distance_to_footprint(point: Vector3) -> float:
	var size: Vector3 = definition.footprint_size if definition != null else Vector3.ONE
	var local: Vector3 = global_transform.affine_inverse() * point
	return Vector2(maxf(absf(local.x) - size.x * 0.5, 0.0), maxf(absf(local.z) - size.z * 0.5, 0.0)).length()


## Moves the build line up with progress (solid below it, ghost above),
## shrinks the pile, and scales the HP.
func _refresh_construction() -> void:
	if is_blueprint() and is_inside_tree():
		var cut: float = global_position.y + build_line_height()
		for material in _build_materials:
			material.set_shader_parameter("build_clip_y", cut)
		if _ghost_material != null:
			_ghost_material.set_shader_parameter("clip_y", cut)
		var left: int = ceili(_pile.size() * (1.0 - build_progress))
		for i in range(_pile.size()):
			_pile[i].visible = i < left
	if _build_bar != null:
		_build_bar.set_value(int(round(build_progress * 20.0)), 20)
	if is_blueprint():
		var scaled: int = int(round(get_max_hp() * lerpf(BLUEPRINT_START_HP, 1.0, build_progress)))
		current_hp = maxi(1, scaled - _construction_damage)
		_refresh_hp_label()


func _physics_process(delta: float) -> void:
	_auto_attack_timer += delta
	if _auto_attack_timer < auto_attack_interval:
		return
	var target: Node3D = null
	var best: float = auto_attack_range
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob: Node3D = node as Node3D
		if mob == null:
			continue
		var d: float = mob.global_position.distance_to(global_position)
		if d < best:
			best = d
			target = mob
	if target != null:
		_auto_attack_timer = 0.0
		target.take_damage(auto_attack_damage, self)


func take_damage(amount: int, _source: Node = null) -> void:
	if amount <= 0 or current_hp <= 0:
		return
	if is_blueprint():
		_construction_damage += amount
	current_hp = max(0, current_hp - amount)
	damaged.emit(current_hp)
	Fx.flash(self)
	if current_hp > 0:
		AudioManager.play_sfx(&"structure_hit", global_position)
	_refresh_hp_label()
	if current_hp == 0:
		Fx.burst(&"build", global_position + Vector3(0, 0.5, 0))
		destroyed.emit()
		PlaytestLog.write("building_destroyed id=%s day=%d" % [
			definition.id if definition != null else &"?", TimeManager.day_number
		])
		queue_free()


func _refresh_hp_label() -> void:
	if _hp_bar == null or definition == null:
		return
	_hp_bar.set_value(current_hp, definition.max_hp)


func get_max_hp() -> int:
	return definition.max_hp if definition != null else current_hp


func get_missing_hp() -> int:
	return maxi(0, get_max_hp() - current_hp) if current_hp > 0 else 0


func repair(amount: int) -> void:
	if amount <= 0 or definition == null:
		return
	if current_hp <= 0:
		return
	current_hp = min(definition.max_hp, current_hp + amount)
	repaired.emit(current_hp)
	_refresh_hp_label()
