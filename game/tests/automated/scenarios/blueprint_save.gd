extends "res://tests/automated/smoke_scenario.gd"

## A half-built blueprint through save and Continue.


func run() -> void:
	await _run_blueprint_save_scenario()


## A half-built blueprint survives Continue as a blueprint,
## dressed again (ghost, site, build line at its progress), and the hero
## then finishes it.
func _run_blueprint_save_scenario() -> void:
	print("smoke: --- blueprint save scenario ---")
	await _start_fresh_run()
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var def: BuildingDefinition = BuildManager.get_definition(&"watch_post")
	var where: Vector3 = player.global_position + Vector3(3.5, 0, 2.0)
	var post: Building = BuildManager.place_blueprint(def, Transform3D(Basis(Vector3.UP, 0.6), where))
	player.set_physics_process(false)  # leave it half built
	post.add_build_progress(def.build_seconds * 0.5)
	await get_tree().process_frame
	var hp_before: int = post.current_hp
	var clip_before: float = float((post.get("_ghost_material") as ShaderMaterial).get_shader_parameter("clip_y"))
	var data: Dictionary = RunSession.snapshot()
	await _continue_from(SaveManager.parse(SaveManager.serialize(data)))
	await get_tree().process_frame
	var loaded: Building = null
	for node in get_tree().get_nodes_in_group(Building.BLUEPRINT_GROUP):
		if node is Building and (node as Building).definition.id == &"watch_post":
			loaded = node as Building
	_check(loaded != null and is_equal_approx(loaded.build_progress, 0.5) and loaded.current_hp == hp_before
		and loaded.global_position.distance_to(where) < 0.01 and absf(loaded.global_rotation.y - 0.6) < 0.01,
		"Continue keeps a half-built watch post as a blueprint (50%%, %d HP, same spot)" % hp_before)
	if loaded == null:
		return
	var ghost_material: ShaderMaterial = loaded.get("_ghost_material") as ShaderMaterial
	var clip_after: float = float(ghost_material.get_shader_parameter("clip_y")) if ghost_material != null else -1000.0
	_check(loaded.get_node_or_null("Ghost") != null and loaded.get_node_or_null("Site") != null
		and absf(clip_after - clip_before) < 0.02 and not loaded.is_physics_processing(),
		"it comes back as a ghost on its site, the build line where it was (%.2f m), not shooting yet" % clip_after)
	player = get_tree().get_first_node_in_group("player")
	var t: float = 0.0
	while loaded.is_blueprint() and t < 12.0:
		await _wait(0.1)
		t += 0.1
	_check(loaded.is_built() and loaded.is_physics_processing(), "the hero finishes the loaded blueprint (%.1fs) and it works" % t)
