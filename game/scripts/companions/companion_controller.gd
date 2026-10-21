class_name Companion
extends Hero

## Companion
##
## Task-driven AI used by family / pet companions. Always present in
## the world; the player assigns tasks via hotkeys (see HUD hint).
## Mobs can hurt companions (health lives in Hero); a downed companion
## stays down until the next dawn, then gets back up at full health.
##
## Feature 034: the companion is a hero too (Nela, or Leo when the
## player plays Nela). Body, stats, speed, reach and fighting style come
## from the party's HeroDefinition; `definition` keeps the task tuning.
##
## Playtest 1 (feature 044): every task walks along the navigation mesh
## (NavSteer) instead of a straight line, and a watchdog re-paths,
## sidesteps or finally hops her free when she is pressed against a prop.

signal task_changed(new_task: int)

enum Task { IDLE, FOLLOW_PLAYER, GUARD_BASE, GATHER_NEAREST, REPAIR }

## Seconds between the companion's hammer taps (slower than the player's).
const REPAIR_TAP_SECONDS: float = 1.0
const REPAIR_REACH: float = 1.9

@export var definition: CompanionDefinition
@export var follow_distance: float = 2.5
@export var guard_radius: float = 3.5
@export var detection_radius: float = 6.0

var current_task: int = Task.IDLE

@onready var _task_label: Label3D = $TaskLabel
var _hp_bar: HealthBar3D = null

var _player: Node3D = null
var _base_core: Node3D = null
var _repair_timer: float = 0.0
## The hammering rhythm while building or repairing (feature 045).
var _build_beat: BuildBeat = BuildBeat.new()
var _tool_busy: bool = false
var move_speed: float = 4.8

const BANDAGE_HEAL: int = 25
## Re-path when the walk goal moves this far.
const NAV_RETARGET_DISTANCE: float = 0.5
## Moving slower than this share of move_speed counts as stuck.
const STUCK_PROGRESS_RATIO: float = 0.25
const STUCK_REPATH_SECONDS: float = 1.0
const STUCK_SNAP_SECONDS: float = 3.0

var _agent: NavigationAgent3D = null
var _nav_goal: Vector3 = Vector3.INF
var _stuck_seconds: float = 0.0
var _detour_point: Vector3 = Vector3.ZERO
var _detour_remaining: float = 0.0
## How often the watchdog had to hop the companion free (for tests).
var unstuck_count: int = 0


func _init() -> void:
	# The companion's health tuning (Hero holds the fields).
	max_hp = 40
	regen_per_second = 1.0
	hurt_invulnerability_seconds = 0.5
	# The companion's attack defaults (the definitions overwrite them).
	attack_damage = 0
	attack_cooldown_seconds = 0.6


func _enter_tree() -> void:
	# Before the Visual child's _ready builds the model.
	# An empty `hero` takes GameManager.party_companion().
	if hero == null:
		hero = GameManager.party_companion()
	if hero == null or is_in_group(HeroRoster.group_for(hero.id)):
		return
	add_to_group(HeroRoster.group_for(hero.id))
	stats = hero.stats
	HeroBody.apply(self, hero)


func _ready() -> void:
	add_to_group("companions")
	_agent = NavSteer.make_agent(self)
	_refresh_world_refs()
	_update_task_label()
	attack_damage = definition.attack_damage if definition != null else 0
	if definition != null:
		move_speed = definition.move_speed
		attack_range = definition.attack_range
		attack_cooldown_seconds = definition.attack_cooldown_seconds
	if hero != null:
		move_speed = hero.companion_move_speed
	_read_attack_tuning()
	if stats != null:
		attack_damage = stats.base_attack_damage
		max_hp = stats.base_max_health
	current_hp = max_hp
	ProgressionManager.register_character(self, stats)
	if not ProgressionManager.level_up.is_connected(_on_level_up):
		ProgressionManager.level_up.connect(_on_level_up)
	TimeManager.dawn_started.connect(_on_dawn_started)
	_hp_bar = HealthBar3D.attach(self, 2.2, "hero", 1.1)
	health_changed.connect(func(hp: int, max_value: int) -> void: _hp_bar.set_value(hp, max_value))
	_hp_bar.set_value.call_deferred(current_hp, max_hp)


# --- Health (the role's part; see Hero) ------------------------------

func _show_hurt(amount: int) -> void:
	Fx.flash(self)
	Fx.float_text(self, "-%d" % amount, Color(1, 0.6, 0.4))
	AudioManager.play_sfx(hero.hurt_sfx if hero != null else &"sibling_hurt", global_position)


func _on_down_changed(down: bool) -> void:
	if down:
		cancel_gather()
		PlaytestLog.write("companion_knocked_out day=%d" % TimeManager.day_number)
	_update_task_label()


## A downed companion gets back up at dawn, at full health.
func _on_dawn_started(_day_number: int) -> void:
	if is_down():
		revive(max_hp)
		Fx.burst(&"heal", global_position)


func set_task(task: int) -> void:
	if task == current_task:
		return
	cancel_gather()
	current_task = task
	task_changed.emit(current_task)
	_update_task_label()


## A bandage: +25 HP, or gets a downed companion up (with 25 HP).
## False when they do not need one.
func apply_bandage() -> bool:
	if is_down():
		revive(BANDAGE_HEAL)
	elif current_hp < max_hp:
		heal(BANDAGE_HEAL)
	else:
		return false
	Fx.float_text(self, "+%d HP" % BANDAGE_HEAL, Color(0.5, 1, 0.5))
	Fx.burst(&"heal", global_position)
	AudioManager.play_sfx(&"bandage", global_position)
	return true


func get_task_name() -> String:
	match current_task:
		Task.IDLE: return "Idle"
		Task.FOLLOW_PLAYER: return "Follow Player"
		Task.GUARD_BASE: return "Guard Base"
		Task.GATHER_NEAREST: return "Gather"
		Task.REPAIR: return "Repair"
	return "?"


func _physics_process(delta: float) -> void:
	if definition == null:
		return
	_tick_attack(delta)
	_tick_health(delta)
	if is_down():
		_build_beat.stop(_visual)
		return
	_tool_busy = false

	if _player == null or _base_core == null:
		_refresh_world_refs()

	match current_task:
		Task.IDLE:
			_tick_idle()
		Task.FOLLOW_PLAYER:
			_tick_follow_player()
		Task.GUARD_BASE:
			_tick_guard_base()
		Task.GATHER_NEAREST:
			_tick_gather_nearest()
		Task.REPAIR:
			_tick_repair(delta)
	if not _tool_busy:
		_build_beat.stop(_visual)

	var planar_speed: float = Vector2(velocity.x, velocity.z).length()
	_visual.set_locomotion(planar_speed)
	if planar_speed > 0.2 and not _visual.is_in_action():
		_visual.face(velocity, delta)
	elif is_gathering():
		_visual.face(gather_target().global_position - global_position, delta)
		if not _visual.is_in_action():
			_visual.play_action(&"gather", 1.3)


func _tick_idle() -> void:
	_stop()


func _tick_follow_player() -> void:
	if _player == null or _flat_distance(_player.global_position) <= follow_distance:
		_stop()
		return
	_walk_to(_player.global_position)


func _tick_guard_base() -> void:
	if _base_core == null:
		_stop()
		return
	# First priority: kill nearby mobs.
	var mob: Node3D = nearest_mob(get_attack_range())
	if mob != null:
		_stop()
		if is_attack_ready():
			attack(mob)
		return
	# Second: move into guard radius if outside.
	if _flat_distance(_base_core.global_position) > guard_radius:
		_walk_to(_base_core.global_position)
		return
	# Approach the nearest detected mob if any.
	var detected: Node3D = nearest_mob(detection_radius)
	if detected != null:
		_walk_to(detected.global_position)
	else:
		_stop()


func _tick_gather_nearest() -> void:
	# If we're currently gathering a node, wait for it; gather.gd's
	# Timer drives completion. The node calls ResourceManager.add()
	# itself and emits "gathered" — we just need to wait, then look
	# for the next nearest.
	if is_gathering():
		# Stand still while gathering.
		_stop()
		return

	var target: ResourceNode = _find_nearest_resource_node()
	if target == null:
		_stop()
		return
	# Begin gathering when adjacent.
	if _flat_distance(target.global_position) < 1.8:
		_stop()
		start_gather(target)
		return
	_walk_to(target.global_position)


## Builds waiting blueprints first (feature 044), then fixes the most
## damaged structure (the campfire first when it is low), fighting any
## imp that comes within reach. With nothing to do, or no wood left,
## the companion guards the camp instead.
func _tick_repair(delta: float) -> void:
	_repair_timer = maxf(0.0, _repair_timer - delta)
	var mob: Node3D = nearest_mob(get_attack_range())
	var site: Building = BuildManager.next_blueprint() if mob == null else null
	if site != null:
		if site.distance_to_footprint(global_position) > REPAIR_REACH - 0.6:
			_walk_to(site.global_position)
			return
		_stop()
		_tool_busy = true
		if _build_beat.tick(delta, _visual, site):
			_visual.face_instantly(site.global_position - global_position)
		if site.add_build_progress(delta, self):
			_build_beat.stop(_visual)
		return
	var target: Node3D = Repair.most_damaged(get_tree())
	if mob != null or target == null or not ResourceManager.has(Repair.WOOD_ID, Repair.WOOD_PER_TAP):
		_tick_guard_base()
		return
	if _flat_distance(target.global_position) > REPAIR_REACH + _node_radius(target):
		_walk_to(target.global_position)
		return
	_stop()
	_tool_busy = true
	_visual.face(target.global_position - global_position, delta)
	if _repair_timer <= 0.0:
		_repair_timer = REPAIR_TAP_SECONDS
		if Repair.tap(target, self):
			_build_beat.swing(_visual)


# --- Walking (feature 044: nav paths and a stuck watchdog) -------------

## Walks along the nav path toward `goal`. If the companion barely moves
## for STUCK_REPATH_SECONDS it re-paths and sidesteps; after
## STUCK_SNAP_SECONDS it hops to open ground a little toward the goal.
func _walk_to(goal: Vector3) -> void:
	var delta: float = get_physics_process_delta_time()
	goal.y = global_position.y
	if goal.distance_to(_nav_goal) > NAV_RETARGET_DISTANCE or _agent.is_navigation_finished():
		_nav_goal = goal
		_agent.target_position = goal
	if _detour_remaining > 0.0:
		_detour_remaining -= delta
		if _flat_distance(_detour_point) < 0.3:
			_detour_remaining = 0.0
		velocity = _flat_direction(_detour_point) * move_speed
	else:
		velocity = NavSteer.velocity(_agent, self, goal, move_speed)
	var before: Vector3 = global_position
	move_and_slide()
	_check_stuck(goal, before, delta)


func _stop() -> void:
	velocity = Vector3.ZERO
	move_and_slide()
	_stuck_seconds = 0.0
	_detour_remaining = 0.0


func _check_stuck(goal: Vector3, before: Vector3, delta: float) -> void:
	var wanted: float = move_speed * delta
	var moved: float = Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if wanted <= 0.0 or moved >= wanted * STUCK_PROGRESS_RATIO:
		_stuck_seconds = maxf(0.0, _stuck_seconds - delta * 2.0)
		return
	_stuck_seconds += delta
	if _stuck_seconds >= STUCK_SNAP_SECONDS:
		var ahead: Vector3 = global_position + _flat_direction(goal) * 1.2
		global_position = NavSteer.closest_point(_agent, ahead)
		Fx.burst(&"step_dust", global_position)
		_stuck_seconds = 0.0
		_detour_remaining = 0.0
		_agent.target_position = goal
		unstuck_count += 1
	elif _stuck_seconds >= STUCK_REPATH_SECONDS and _detour_remaining <= 0.0:
		# Re-path, and sidestep off whatever we are pressed against.
		_agent.target_position = goal
		var side: Vector3 = _flat_direction(goal).cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
		_detour_point = NavSteer.closest_point(_agent, global_position + side * 1.2)
		_detour_remaining = 0.8


func _flat_direction(point: Vector3) -> Vector3:
	var to: Vector3 = point - global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.001 else Vector3.FORWARD


# --- Attack (the role's part; see Hero) ------------------------------

func _is_companion_role() -> bool:
	return true


func _show_attack(target: Node3D) -> void:
	_visual.face_instantly(target.global_position - global_position)
	_visual.play_action(&"attack", 1.45)


## The companion's quick hit: it lands at once, with a sparkle.
func _swing(target: Node3D) -> void:
	_land_swing(target, &"sparkle")


func _on_level_up(character: Node, _new_level: int) -> void:
	if character != self or stats == null:
		return
	attack_damage += stats.attack_damage_per_level
	_hp_bar.set_level(_new_level)
	max_hp += stats.max_health_per_level
	current_hp = min(max_hp, current_hp + stats.max_health_per_level)
	health_changed.emit(current_hp, max_hp)
	if not ProgressionManager.is_restoring:
		Fx.float_text(self, "LEVEL UP!", Color(1.0, 0.85, 0.4), 2.7)


func _find_nearest_resource_node() -> ResourceNode:
	# Resource nodes are on collision_layer 3 (1+2). Walk the scene
	# tree once; this is a prototype with few nodes, so no spatial
	# index needed.
	var best: ResourceNode = null
	var best_d_sq: float = INF
	var stack: Array = [get_tree().current_scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == null:
			continue
		if node is ResourceNode and _can_gather(node as ResourceNode):
			var resource_node: ResourceNode = node as ResourceNode
			var d_sq: float = resource_node.global_position.distance_squared_to(global_position)
			if d_sq < best_d_sq:
				best_d_sq = d_sq
				best = resource_node
		for child in node.get_children():
			stack.append(child)
	return best


## A node worth walking to: gatherable, with room in the stash, and not
## being gathered by the other hero (she would stand there waiting).
func _can_gather(node: ResourceNode) -> bool:
	return node.is_gatherable and not node.is_stash_full() and not node.is_taken_by_other(self)


func _refresh_world_refs() -> void:
	if _player == null:
		var players: Array = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			_player = players[0] as Node3D
	if _base_core == null:
		var bases: Array = get_tree().get_nodes_in_group("base_core")
		if not bases.is_empty():
			_base_core = bases[0] as Node3D


func _update_task_label() -> void:
	if _task_label != null:
		# The HUD task buttons show the task; the label only shows sleep.
		_task_label.text = "Zzz" if is_down() else ""
