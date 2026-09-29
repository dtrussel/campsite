extends Node

## Scratch balance simulation (not a pass/fail test). Plays nights
## unattended with the given companion task and prints HP at each dawn.
##   -- <companion task 0-4> <fight|idle> [no_beasts] [7]
## "fight" chases the nearest mob like an active player; days are
## skipped, so the boy is healed to full at each nightfall.

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
var companion_task: int = 0
var player_fights: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0: companion_task = int(args[0])
	if args.size() > 1: player_fights = args[1] == "fight"
	var no_beasts: bool = args.has("no_beasts")
	var nights: int = 7 if args.has("7") else 3
	GameManager.nights_to_win = nights
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().get_first_node_in_group("controls_overlay").close()
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var companion: Node = get_tree().get_first_node_in_group("companions")
	companion.set_task(companion_task)
	if no_beasts:
		get_tree().get_first_node_in_group("mob_spawner").set("heavy_counts", PackedInt32Array())
	player.global_position = Vector3(1.5, 0, 1.5)
	Engine.time_scale = 6.0
	var fire: BaseCore = get_tree().get_first_node_in_group("base_core")
	for night in range(1, nights + 1):
		while TimeManager.current_phase != TimeManager.Phase.NIGHT:
			TimeManager.skip_phase()
		# A real day (120 s at 1.5 HP/s) regenerates the boy fully.
		player.heal(player.max_hp)
		var t: float = 0.0
		while TimeManager.current_phase == TimeManager.Phase.NIGHT and GameManager.is_playing():
			await get_tree().create_timer(0.1, true, false, true).timeout
			t += 0.1 * Engine.time_scale
			if player_fights:
				# An active player: chase the nearest mob, like a kid clicking it.
				if int(player.get("command")) == 0:
					var nearest: Node3D = null
					for mob in get_tree().get_nodes_in_group("mobs"):
						if nearest == null or (mob as Node3D).global_position.distance_to(player.global_position) \
								< nearest.global_position.distance_to(player.global_position):
							nearest = mob as Node3D
					if nearest != null:
						player.command_attack(nearest)
		print("sim: night %d end t=%.0fs fire=%d/%d boy=%d/%d sib=%d ko=%s state=%d reason=%s" % [
			night, t, fire.current_hp, fire.max_hp, player.current_hp, player.max_hp,
			companion.current_hp, companion.is_knocked_out, GameManager.run_state, GameManager.end_reason])
		if not GameManager.is_playing():
			break
	get_tree().quit(0)
