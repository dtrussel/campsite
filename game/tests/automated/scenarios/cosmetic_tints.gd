extends "res://tests/automated/smoke_scenario.gd"

## Outfit tints and tent colours that badges unlock.


func run() -> void:
	await _run_cosmetic_tints_scenario()


## A badge unlocks an outfit tint and a tent colour.
## Hero select's outfit row will not pick a locked one; an unlocked one
## is kept in the profile (after a restart too) and the run dresses the
## hero (not the companion) and the tent in it.
func _run_cosmetic_tints_scenario() -> void:
	print("smoke: --- cosmetic tints scenario ---")
	await _close_main()
	Profile.delete()
	var screen: Node = await _open_hero_select(0)
	var moss: Button = screen.call("outfit_button", &"moss") as Button
	_check(moss != null and moss.disabled, "a locked outfit tint is shown but can't be picked")
	moss.pressed.emit()
	_check(Cosmetics.outfit_id(&"leo") == Cosmetics.DEFAULT_OUTFIT and not Cosmetics.choose_outfit(&"leo", &"moss"),
		"a locked outfit tint is not kept, even when pressed")
	screen.queue_free()

	# Earning First Night unlocks Moss; Builder unlocks the Berry tent.
	Profile.grant_badge_for_tests(&"first_night")
	Profile.grant_badge_for_tests(&"builder")
	screen = await _open_hero_select(0)
	moss = screen.call("outfit_button", &"moss") as Button
	_check(moss != null and not moss.disabled, "earning First Night unlocks the Moss outfit")
	moss.pressed.emit()
	(screen.call("tent_button", &"berry") as Button).pressed.emit()
	screen.queue_free()
	Profile.reload()
	_check(Cosmetics.outfit_id(&"leo") == &"moss" and Cosmetics.outfit_id(&"nela") == Cosmetics.DEFAULT_OUTFIT
		and Cosmetics.tent_id() == &"berry", "the picked outfit (Leo's only) and tent colour are kept after a restart")

	var config: RunConfig = _config()
	config.hero_id = &"leo"
	config.companion_id = &"nela"
	await _start_fresh_run(config)
	var moss_color: Color = Color(0.72, 0.9, 0.62)
	var berry_color: Color = Color(1.0, 0.68, 0.74)
	var leo: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	var nela: Node3D = Party.companion()
	_check(_albedo_near(_outfit_mesh(leo, "Leo"), moss_color), "the run dresses Leo in the Moss outfit")
	_check(_albedo_near(_outfit_mesh(nela, "Nela"), Color.WHITE), "the companion keeps her own (default) outfit")
	var tent: MeshInstance3D = null
	for i in 30:  # the tent is styled a frame after it is placed
		var tents: Array[Node] = get_tree().get_nodes_in_group("tent")
		if not tents.is_empty():
			tent = (tents[0] as Node).find_child("tent", true, false) as MeshInstance3D
		if tent != null and tent.has_meta(&"stylized"):
			break
		await get_tree().process_frame
	_check(_albedo_near(tent, berry_color), "the tent is the Berry colour")
	await _close_main()
	Profile.delete()


func _open_hero_select(index: int) -> Node:
	var screen: Node = (load("res://scenes/ui/HeroSelect.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	screen.call("select", index, false)
	return screen


func _outfit_mesh(hero: Node, mesh_name: String) -> MeshInstance3D:
	if hero == null:
		return null
	return hero.find_child(mesh_name, true, false) as MeshInstance3D


## Whether mesh's styled painted material is tinted `color`.
func _albedo_near(mesh: MeshInstance3D, color: Color) -> bool:
	if mesh == null:
		return false
	var material: ShaderMaterial = mesh.get_surface_override_material(0) as ShaderMaterial
	if material == null:
		return false
	var albedo: Color = material.get_shader_parameter("albedo_color")
	return albedo.is_equal_approx(color)
