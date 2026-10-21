class_name BarkDirector
extends Node

## BarkDirector
##
## Lets the siblings talk during a run (feature 037): it listens to the
## game's events, picks who speaks (keyed by who is played), shows the
## line in a SpeechBubble and plays its recording, or a chirp until the
## recordings arrive. Cooldowns keep it from chattering: one shared gap
## between barks, one per trigger, and once-a-night or once-a-run
## triggers. Urgent
## barks (hurt, knocked out, danger) skip the shared gap.
## Added to the gameplay scene by Main.

const GLOBAL_COOLDOWN: float = 6.0
## The companion answers this long after the played hero (at least).
const REPLY_DELAY: float = 0.8
const LOW_HP_RATIO: float = 0.3
const DANGER_RANGE: float = 5.0
const DANGER_POLL_SECONDS: float = 0.5
## A mob counts as behind the player below this facing dot product.
const BEHIND_DOT: float = -0.3
const MIN_SECONDS: float = 2.5
const CHIRP_FRONT: float = 0.4

## Seconds of unpaused run time; cooldowns count in it.
var clock: float = 0.0
var _last_any: float = -INF
var _last_trigger: Dictionary = {}  # trigger -> clock
var _once_day: Dictionary = {}  # trigger -> day number
var _last_line: Dictionary = {}  # "trigger:speaker" -> line id
var _hp_ratio: Dictionary = {}  # hero node -> last health ratio
var _lantern_stage: int = 0
var _poll: float = 0.0


func _ready() -> void:
	name = "BarkDirector"
	add_to_group("bark_director")
	GameManager.run_started.connect(_on_run_started)
	TimeManager.sunset_warning.connect(func(_seconds: float) -> void: bark(&"sunset"))
	TimeManager.night_started.connect(func(_day: int) -> void: bark(&"night_start"))
	ProgressionManager.level_up.connect(func(character: Node, _level: int) -> void: bark(&"level_up", character))
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	clock += delta
	_poll += delta
	if _poll < DANGER_POLL_SECONDS:
		return
	_poll = 0.0
	if danger_behind():
		bark(&"danger_behind")


## Shows a bark for `trigger` (about `subject`, for subject triggers).
## Returns whether it spoke.
func bark(trigger: StringName, subject: Node = null) -> bool:
	if not GameManager.is_playing() or get_tree().paused:
		return false
	var tuning: Dictionary = BarkLibrary.trigger(trigger)
	if tuning.is_empty():
		return false
	var urgent: bool = bool(tuning.get("urgent", false))
	if clock - float(_last_trigger.get(trigger, -INF)) < float(tuning.get("cooldown", 0.0)):
		return false
	var once: String = String(tuning.get("once", ""))
	if once == "night" and int(_once_day.get(trigger, -1)) == TimeManager.day_number:
		return false
	if once == "run" and _once_day.has(trigger):
		return false
	if not urgent and (clock - _last_any < GLOBAL_COOLDOWN or _story_open()):
		return false
	var speakers: Array = _speakers(String(tuning.get("role", "")), subject, trigger)
	if speakers.is_empty():
		return false
	_last_trigger[trigger] = clock
	_last_any = clock
	_once_day[trigger] = TimeManager.day_number
	_speak_all(trigger, speakers)
	return true


## Whether a mob is close behind the played hero, or close and off-screen.
func danger_behind() -> bool:
	var player: Node3D = _player()
	if player == null or not player.has_method("get_facing"):
		return false
	var camera: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	var facing: Vector3 = player.call("get_facing")
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob: Node3D = node as Node3D
		if mob == null:
			continue
		var to_mob: Vector3 = mob.global_position - player.global_position
		to_mob.y = 0.0
		if to_mob.length() > DANGER_RANGE or to_mob.length() < 0.01:
			continue
		if to_mob.normalized().dot(facing) < BEHIND_DOT:
			return true
		if camera != null and not camera.is_position_in_frustum(mob.global_position):
			return true
	return false


## The hero id a party node speaks as, or &"".
static func speaker_id(node: Node) -> StringName:
	if node == null:
		return &""
	if node.is_in_group("player"):
		return GameManager.hero_id
	if node.is_in_group("companions"):
		return GameManager.companion_id
	return &""


func _speakers(role: String, subject: Node, trigger: StringName) -> Array:
	var player: Node3D = _player()
	var companion: Node3D = _companion()
	var awake: bool = companion != null and not (companion is Hero and (companion as Hero).is_down())
	match role:
		"hero":
			return [player] if player != null else []
		"companion":
			# Back on their feet is the one line a knocked-out companion says.
			return [companion] if companion != null and (awake or trigger == &"companion_up") else []
		"subject":
			var node: Node3D = subject as Node3D
			return [node] if node != null and speaker_id(node) != &"" else []
		"call_response":
			var out: Array = []
			if player != null:
				out.append(player)
			if awake:
				out.append(companion)
			return out
	return []


func _speak_all(trigger: StringName, speakers: Array) -> void:
	for i in speakers.size():
		var node: Node3D = speakers[i] as Node3D
		if not is_instance_valid(node) or not node.is_inside_tree():
			return
		var seconds: float = _speak(trigger, node)
		if i < speakers.size() - 1:
			await get_tree().create_timer(maxf(REPLY_DELAY, seconds - CHIRP_FRONT), false).timeout


## One line over one hero; returns how long its audio plays.
func _speak(trigger: StringName, node: Node3D) -> float:
	var speaker: StringName = speaker_id(node)
	var key: String = "%s:%s" % [trigger, speaker]
	var line: Dictionary = BarkLibrary.pick(trigger, speaker, GameManager.hero_id, String(_last_line.get(key, "")))
	if line.is_empty():
		return 0.0
	var id: String = String(line.get("id", ""))
	_last_line[key] = id
	var seconds: float = AudioManager.play_bark(StoryLibrary.voice(id), String(speaker))
	SpeechBubble.say(node, String(line.get("text", "")), maxf(MIN_SECONDS, seconds + 0.3))
	PlaytestLog.write("bark id=%s day=%d" % [id, TimeManager.day_number])
	return seconds


func _story_open() -> bool:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("story_card") and hud.call("story_card") != null:
		return true
	for book in get_tree().get_nodes_in_group("story_book"):
		if (book as StoryBook).is_open():
			return true
	return false


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _companion() -> Node3D:
	return get_tree().get_first_node_in_group("companions") as Node3D


func _on_run_started() -> void:
	clock = 0.0
	_last_any = -INF
	_last_trigger = {}
	_once_day = {}
	_last_line = {}
	_hp_ratio = {}
	for node in [_player(), _companion()]:
		if node == null:
			continue
		if node.has_signal("health_changed") and not node.health_changed.is_connected(_on_health_changed):
			node.health_changed.connect(_on_health_changed.bind(node))
	var companion: Node = _companion()
	var companion_hero: Hero = companion as Hero
	if companion_hero != null and not companion_hero.down_changed.is_connected(_on_companion_down_changed):
		companion_hero.down_changed.connect(_on_companion_down_changed)
	var lantern: MoonLantern = MoonLantern.find(get_tree())
	if lantern != null:
		_lantern_stage = lantern.stage
		if not lantern.stage_changed.is_connected(_on_lantern_stage):
			lantern.stage_changed.connect(_on_lantern_stage)
	for node in get_tree().get_nodes_in_group("mobs"):
		_hook_mob(node)


func _on_node_added(node: Node) -> void:
	if node is Mob:
		_hook_mob(node)
		var definition: MobDefinition = (node as Mob).definition
		if definition != null and definition.id == &"bramble_beast":
			bark(&"first_beast")
		elif definition != null and definition.is_boss:
			bark.call_deferred(&"boss")


func _hook_mob(node: Node) -> void:
	var mob: Mob = node as Mob
	if mob == null:
		return
	if not mob.stole.is_connected(_on_mob_stole):
		mob.stole.connect(_on_mob_stole)
	if not mob.escaped.is_connected(_on_mob_escaped):
		mob.escaped.connect(_on_mob_escaped)
	if not mob.defeated.is_connected(_on_mob_defeated):
		mob.defeated.connect(_on_mob_defeated)
	var boss: BossController = mob as BossController
	if boss != null and not boss.phase_changed.is_connected(_on_boss_phase):
		boss.phase_changed.connect(_on_boss_phase.bind(boss))


## The Moon-Eater reaches for the lantern (feature 038).
func _on_boss_phase(_phase: int, boss: BossController) -> void:
	if boss.is_draining():
		bark(&"boss_lantern")


func _on_mob_stole(_mob: Node3D, _item_id: StringName, _amount: int) -> void:
	bark(&"thief")


## A gremlin made it back to the woods with its loot (feature 046).
func _on_mob_escaped(_mob: Node3D, _item_id: StringName, _amount: int) -> void:
	bark(&"thief_escaped")


func _on_mob_defeated(mob: Node) -> void:
	# Defeated fires before the loot spills: a full satchel means caught.
	if int(mob.get("loot_amount")) > 0:
		bark(&"thief_caught")


func _on_health_changed(current_hp: int, max_hp: int, node: Node) -> void:
	var ratio: float = float(current_hp) / float(maxi(1, max_hp))
	var before: float = float(_hp_ratio.get(node, 1.0))
	_hp_ratio[node] = ratio
	if current_hp > 0 and ratio < LOW_HP_RATIO and before >= LOW_HP_RATIO:
		bark(&"low_hp", node)


func _on_companion_down_changed(is_down: bool) -> void:
	bark(&"companion_down" if is_down else &"companion_up")


func _on_lantern_stage(stage: int, _max_stage: int) -> void:
	var before: int = _lantern_stage
	_lantern_stage = stage
	if stage > before:
		bark(&"lantern_stage")
