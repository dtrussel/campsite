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
