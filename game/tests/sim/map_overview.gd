extends Node

## Renders bird's-eye views of the whole map for layout review (feature
## 032): a straight-down orthographic plan and two high oblique views,
## in daylight, with the HUD and post effects hidden. Needs a real
## renderer, e.g. under xvfb-run:
##   godot --path . res://tests/sim/map_overview.tscn -- <out_dir>/


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if not args.is_empty() else ProjectSettings.globalize_path("user://overview/")
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await _settle(0.6)
	get_tree().get_first_node_in_group("controls_overlay").close()
	for node in main.get_children():
		if node is CanvasLayer:
			(node as CanvasLayer).visible = false
	var post: Node = main.find_child("PostFx", true, false)
	if post is CanvasLayer:
		(post as CanvasLayer).visible = false
	for node in main.find_children("*", "ResourceNode", true, false):
		var at: Vector2 = Vector2((node as Node3D).global_position.x, (node as Node3D).global_position.z)
		print("layout: %s %s path=%.2f lane=%s zone=%s" % [node.name, at, WorldLayout.path_distance(at),
			WorldLayout.in_lane(at), WorldLayout.Zone.keys()[WorldLayout.zone_at(at)]])
	var camera: Camera3D = Camera3D.new()
	camera.far = 400.0
	add_child(camera)
	camera.current = true
	# Plan view.
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 64.0
	camera.global_transform = Transform3D(Basis.from_euler(Vector3(-PI / 2.0, 0, 0)), Vector3(0, 80, 0))
	await _settle(0.5)
	_shot(out, "plan")
	camera.size = 30.0
	await _settle(0.3)
	_shot(out, "plan_camp")
	# Oblique views from the south and the north-east.
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 40.0
	for view in [["oblique_s", Vector3(0, 30, 34)], ["oblique_ne", Vector3(26, 26, -26)], ["oblique_w", Vector3(-34, 22, 6)]]:
		camera.global_position = view[1]
		camera.look_at(Vector3(0, 0, 0), Vector3.UP)
		await _settle(0.3)
		_shot(out, view[0])
	# Game-camera views over each part of the map, with post effects.
	if post is CanvasLayer:
		(post as CanvasLayer).visible = true
	camera.fov = 34.0
	var pitch: float = deg_to_rad(42.0)
	for spot in [["game_camp", Vector3(0, 0, 0)], ["game_pines", Vector3(-8, 0, -8)], ["game_pond", Vector3(9, 0, -9)],
			["game_woodlot", Vector3(-8, 0, 7)], ["game_hollow", Vector3(9, 0, 7)], ["game_road", Vector3(0, 0, 13)],
			["game_lane_e", Vector3(15, 0, 0)]]:
		camera.global_position = spot[1] + Vector3(0, 15.5 * sin(pitch), 15.5 * cos(pitch))
		camera.look_at(spot[1], Vector3.UP)
		await _settle(0.3)
		_shot(out, spot[0])
	get_tree().quit()


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
	await RenderingServer.frame_post_draw


func _shot(out: String, label: String) -> void:
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("overview: ", label)
