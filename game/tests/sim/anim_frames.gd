extends Node

## Captures a filmstrip of animation frames for review (feature 023):
## Leo running while he swings (upper-body layer), then turning sharply
## (lean). Needs a real renderer, e.g. under xvfb-run:
##   xvfb-run -a godot --path game --rendering-driver opengl3 \
##       res://tests/sim/anim_frames.tscn -- /some/dir

var _out: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_out = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else ProjectSettings.globalize_path("user://anim_frames/")
	DirAccess.make_dir_recursive_absolute(_out)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await _settle(0.5)
	get_tree().get_first_node_in_group("controls_overlay").close()
	var rig: Node = get_tree().get_first_node_in_group("camera_rig")
	if rig != null:
		rig.set("_zoom", 0.65)
		rig.set("_zoom_target", 0.65)
	var player: Node3D = get_tree().get_first_node_in_group("player")
	player.global_position = Vector3(-6, 0, 3)
	await _settle(0.6)
	if OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "beast":
		await _beast_frames(player)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "gremlin":
		await _gremlin_frames(player)
		get_tree().quit()
		return
	var visual: CharacterVisual = player.get_node("Visual") as CharacterVisual
	# Run right and swing: the legs should keep running.
	player.command_move(Vector3(8, 0, 3))
	await _settle(0.35)
	visual.play_action(&"attack", 1.2)
	for i in 6:
		await _settle(0.09)
		_shot("run_swing_%d" % i)
	# A sharp turn: lean into it.
	player.command_move(player.global_position + Vector3(0, 0, -8))
	for i in 3:
		await _settle(0.08)
		_shot("turn_%d" % i)
	get_tree().quit()


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
	await RenderingServer.frame_post_draw


func _shot(label: String) -> void:
	get_viewport().get_texture().get_image().save_png(_out.path_join(label + ".png"))
	print("anim_frames: ", label)


## Feature 026: the Bramble Beast rising, stomping to a fence, slamming
## it and collapsing. Pass `beast` after the output dir.
func _beast_frames(player: Node3D) -> void:
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var spawner: Node = get_tree().get_first_node_in_group("mob_spawner")
	var beast_def: MobDefinition = spawner.get("heavy_definition")
	var fence: Node3D = BuildManager.get_definition(&"wooden_fence").get_scene().instantiate() as Node3D
	get_tree().current_scene.add_child(fence)
	fence.global_position = Vector3(4.2, 0, 4.4)
	var beast: Node3D = beast_def.get_scene().instantiate() as Node3D
	get_tree().current_scene.add_child(beast)
	beast.global_position = Vector3(1.6, 0, 3.6)
	player.global_position = Vector3(-0.8, 0, 4.4)
	for i in 6:
		await _settle(0.3)
		_shot("beast_spawn_%d" % i)
	for i in 4:
		await _settle(0.15)
		_shot("beast_walk_%d" % i)
	var t: float = 0.0
	while beast.get("state") != Mob.State.ATTACKING and t < 8.0:
		await _settle(0.05)
		t += 0.05
	for i in 8:
		_shot("beast_slam_%d" % i)
		await _settle(0.1)
	beast.call("take_damage", 999, player)
	for i in 4:
		await _settle(0.25)
		_shot("beast_death_%d" % i)


## Feature 027: the Mushroom Gremlin popping up, sneaking to the campfire,
## grabbing loot, scurrying off, and plopping over when caught. Pass
## `gremlin` after the output dir.
func _gremlin_frames(player: Node3D) -> void:
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	ResourceManager.add(&"wood", 8)
	var spawner: Node = get_tree().get_first_node_in_group("mob_spawner")
	var gremlin_def: MobDefinition = spawner.get("sneak_definition")
	var gremlin: Node3D = gremlin_def.get_scene().instantiate() as Node3D
	get_tree().current_scene.add_child(gremlin)
	gremlin.global_position = Vector3(3.2, 0, 3.4)
	player.global_position = Vector3(0.4, 0, 3.0)
	for i in 4:
		await _settle(0.3)
		_shot("gremlin_spawn_%d" % i)
	for i in 4:
		await _settle(0.12)
		_shot("gremlin_sneak_%d" % i)
	var t: float = 0.0
	while int(gremlin.get("loot_amount")) == 0 and t < 8.0:
		await _settle(0.05)
		t += 0.05
	for i in 3:
		_shot("gremlin_grab_%d" % i)
		await _settle(0.1)
	for i in 3:
		await _settle(0.12)
		_shot("gremlin_flee_%d" % i)
	gremlin.call("take_damage", 999, player)
	for i in 3:
		await _settle(0.3)
		_shot("gremlin_death_%d" % i)

