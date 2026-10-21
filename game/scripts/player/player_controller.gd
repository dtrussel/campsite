extends Hero

## PlayerController
##
## LoL-style command movement. The pointer (see PointerCommands) issues
## commands: move to a point, attack an imp (walk into range, then
## auto-attack until it dies), gather a resource node (walk to it,
## then gather), use the campfire (walk to it, open crafting), or
## repair a damaged building (walk to it, then hammer until it is fixed
## or the wood runs out; see Repair), or build a blueprint (walk to
## it, then hammer it up; feature 044). An idle hero takes the oldest
## waiting blueprint on its own.
## Paths come from the world's navigation mesh; WASD still works as a
## direct override and cancels the current command.
##
## The played hero's health lives in Hero: mobs hurt them, they
## regenerate slowly outside of night, eating berries heals, and being
## down ends the run (GameManager listens to `down_changed`).
##
## Feature 034: the body, stats and fighting style come from the party's
## HeroDefinition (Leo swings a stick; Nela shoots pebbles from range).
##
## Playtest 1 (feature 044): auto-attack. An idle or gathering hero
## picks the nearest mob within `auto_attack_radius()` and fights it,
## chains to the next one, then goes back to the interrupted gather.
## Any player command wins; the pause menu can switch it off.

signal command_changed(command: int, target: Node)
signal attacked(target: Node)

enum PlayerState { IDLE, MOVING, GATHERING }
enum Command { NONE, MOVE, ATTACK, GATHER, CAMPFIRE, REPAIR, BUILD }

const TORCH_SCENE: PackedScene = preload("res://scenes/buildings/Torch.tscn")
const TORCH_ITEM_ID: StringName = &"torch"
const BERRY_ITEM_ID: StringName = &"berries"
const BERRIES_PER_MEAL: int = 2
const SNACK_ITEM_ID: StringName = &"snack"
const BANDAGE_ITEM_ID: StringName = &"bandage"
## How close the player must be to the companion to bandage them.
const BANDAGE_REACH: float = 3.0
## Distance at which a gather command starts gathering.
const GATHER_REACH: float = 1.5
## Distance at which a campfire command opens crafting.
const CAMPFIRE_REACH: float = 2.6
## Distance (plus the target's radius) at which a repair command hammers.
const REPAIR_REACH: float = 1.4
## How close to a blueprint's footprint edge the hero hammers from.
const BUILD_REACH: float = 0.75
## Seconds into the swing when damage lands (the "wind-up").
const ATTACK_WINDUP: float = 0.22
const REPATH_SECONDS: float = 0.25
## How often an idle hero looks for a mob to auto-attack.
const AUTO_ATTACK_SCAN_SECONDS: float = 0.2

@export var move_speed: float = 4.0
@export var acceleration: float = 30.0
@export var friction: float = 30.0

@export var attack_damage: int = 4
@export var attack_range: float = 2.0
@export var attack_cooldown_seconds: float = 0.65
@export var heal_per_meal: int = 15
@export var heal_per_snack: int = 35
## Half-size of the playable square around the campfire; keeps the boy
## inside the area the camera and mob spawns are designed around.
@export var play_area_half_extent: float = 19.0
## Fight nearby mobs on its own (GameSettings, pause menu).
@export var auto_attack: bool = true

@onready var _interactor: Node = $GatherInteractor

var command: int = Command.NONE
var command_target: Node3D = null

var _state: int = PlayerState.IDLE
var _active_node: ResourceNode = null
var _attack_cooldown_remaining: float = 0.0
var _move_goal: Vector3 = Vector3.ZERO
var _repath_timer: float = 0.0
var _repair_timer: float = 0.0
## The hammering rhythm on BUILD and REPAIR (feature 045).
var _build_beat: BuildBeat = BuildBeat.new()
var _tool_busy: bool = false
var _auto_scan_timer: float = 0.0
## The gather auto-attack interrupted, resumed once no mob is near.
var _resume_node: ResourceNode = null
## Crafting Table upgrade (features 019, 034): the hero's signature
## (Leo's Sturdy Stick, Nela's Slingshot), once per run.
var has_signature: bool = false
var _agent: NavigationAgent3D = null
var _hp_bar: HealthBar3D = null


func _init() -> void:
	# The player's hero's health tuning (Hero holds the fields).
	max_hp = 50
	regen_per_second = 1.2
	hurt_invulnerability_seconds = 0.6


func _enter_tree() -> void:
	# Before the Visual child's _ready builds the model.
	# An empty `hero` takes GameManager.party_hero().
	if hero == null:
		hero = GameManager.party_hero()
	if hero == null or is_in_group(HeroRoster.group_for(hero.id)):
		return
	add_to_group(HeroRoster.group_for(hero.id))
	stats = hero.stats
	move_speed = hero.move_speed
	attack_range = hero.attack_range
	attack_cooldown_seconds = hero.attack_cooldown
	HeroBody.apply(self, hero)


func _ready() -> void:
	add_to_group("player")
	if _interactor != null and _interactor.has_signal("interactable_exited"):
		_interactor.interactable_exited.connect(_on_interactor_exited)
	if stats != null:
		attack_damage = stats.base_attack_damage
		max_hp = stats.base_max_health
	current_hp = max_hp
	auto_attack = GameSettings.auto_attack()
	_agent = NavSteer.make_agent(self)
	ProgressionManager.register_character(self, stats)
	if not ProgressionManager.level_up.is_connected(_on_level_up):
		ProgressionManager.level_up.connect(_on_level_up)
	_hp_bar = HealthBar3D.attach(self, 2.45, "hero", 1.3)
	health_changed.connect(func(hp: int, max_value: int) -> void: _hp_bar.set_value(hp, max_value))
	_hp_bar.set_value.call_deferred(current_hp, max_hp)


func _unhandled_input(event: InputEvent) -> void:
	if is_down() or BuildManager.is_in_build_mode():
		return
	if event.is_action_pressed("interact"):
		if not try_feed_lantern():
			_try_begin_gather()
	elif event.is_action_pressed("attack"):
		_try_attack()
	elif event.is_action_pressed("place_torch"):
		_try_place_torch()
	elif event.is_action_pressed("eat_berries"):
		_try_eat_berries()
	elif event.is_action_pressed("use_bandage"):
		try_use_bandage()


# --- Commands (issued by PointerCommands or tests) -------------------

func command_move(point: Vector3) -> void:
	if not _can_command():
		return
	_cancel_active_gather()
	_resume_node = null
	_set_command(Command.MOVE, null)
	_move_goal = Vector3(point.x, global_position.y, point.z)
	_agent.target_position = _move_goal


func command_attack(target: Node3D) -> void:
	if not _can_command() or target == null:
		return
	_cancel_active_gather()
	_resume_node = null
	_set_command(Command.ATTACK, target)
	_repath_timer = 0.0


func command_gather(node: ResourceNode) -> void:
	if not _can_command() or node == null or not node.is_gatherable:
		return
	_cancel_active_gather()
	_resume_node = null
	_set_command(Command.GATHER, node)
	_agent.target_position = node.global_position


func command_campfire(base: Node3D) -> void:
	if not _can_command() or base == null:
		return
	_cancel_active_gather()
	_set_command(Command.CAMPFIRE, base)
	_agent.target_position = base.global_position


func command_repair(target: Node3D) -> void:
	if not _can_command() or not Repair.needs_repair(target):
		return
	_cancel_active_gather()
	_set_command(Command.REPAIR, target)
	_repair_timer = 0.0
	_agent.target_position = target.global_position


## Walk to a blueprint and hammer it up (feature 044).
func command_build(target: Building) -> void:
	if not _can_command() or target == null or not target.is_blueprint():
		return
	_cancel_active_gather()
	_resume_node = null
	_set_command(Command.BUILD, target)
	_agent.target_position = target.global_position


func stop_commands() -> void:
	_resume_node = null
	_set_command(Command.NONE, null)


## The reach of an attack now: attack_range after perks (Eagle Eye).
## Use this, not attack_range, wherever the reach matters.
func get_attack_range() -> float:
	return attack_range * PerkManager.multiplier(self, &"attack_range")


## How close a mob must be for auto-attack to go for it.
func auto_attack_radius() -> float:
	return maxf(get_attack_range() * 1.3, 3.5)


func get_facing() -> Vector3:
	return Vector3(sin(_visual.rotation.y), 0.0, cos(_visual.rotation.y))


# --- Health (the role's part; see Hero) ------------------------------

func _show_hurt(amount: int) -> void:
	Fx.flash(self)
	Fx.float_text(self, "-%d" % amount, Color(1, 0.45, 0.4))
	Fx.shake(0.18)
	AudioManager.play_sfx(hero.hurt_sfx if hero != null else &"player_hurt", global_position)


## Down: drop whatever the hero was doing. GameManager ends the run.
func _on_down_changed(down: bool) -> void:
	if not down:
		return
	_cancel_active_gather()
	_set_command(Command.NONE, null)
	PlaytestLog.write("player_knocked_out day=%d" % TimeManager.day_number)


# --- Per-frame -----------------------------------------------------------

func _physics_process(delta: float) -> void:
	_attack_cooldown_remaining = max(0.0, _attack_cooldown_remaining - delta)
	_tick_health(delta)
	if is_down():
		_build_beat.stop(_visual)
		return
	_tool_busy = false
	_auto_scan_timer -= delta
	if _auto_scan_timer <= 0.0:
		_auto_scan_timer = AUTO_ATTACK_SCAN_SECONDS
		_tick_auto()

	var desired: Vector3 = Vector3.ZERO
	var input_dir: Vector2 = _keyboard_direction()
	if input_dir.length() > 0.0:
		# Keyboard movement overrides (and cancels) pointer commands.
		if command != Command.NONE:
			_set_command(Command.NONE, null)
		_cancel_active_gather()
		_resume_node = null
		_auto_scan_timer = 1.0  # walking by hand: leave the mobs to the player
		desired = Vector3(input_dir.x, 0.0, input_dir.y).normalized() * move_speed
	elif _state == PlayerState.GATHERING:
		desired = Vector3.ZERO
		if _active_node != null and is_instance_valid(_active_node):
			_visual.face(_active_node.global_position - global_position, delta)
			if not _visual.is_in_action():
				_visual.play_action(_active_node.gather_animation, 1.5)
	else:
		desired = _tick_command(delta)
	if not _tool_busy:
		_build_beat.stop(_visual)

	var rate: float = acceleration if desired.length() > 0.0 else friction
	velocity.x = move_toward(velocity.x, desired.x, rate * delta)
	velocity.z = move_toward(velocity.z, desired.z, rate * delta)
	velocity.y = 0.0
	move_and_slide()
	global_position.x = clampf(global_position.x, -play_area_half_extent, play_area_half_extent)
	global_position.z = clampf(global_position.z, -play_area_half_extent, play_area_half_extent)

	var planar_speed: float = Vector2(velocity.x, velocity.z).length()
	if _state != PlayerState.GATHERING:
		_state = PlayerState.MOVING if planar_speed > 0.2 else PlayerState.IDLE
	_visual.set_locomotion(planar_speed)
	if planar_speed > 0.2 and not _visual.is_in_action():
		_visual.face(velocity, delta)


## Returns the desired velocity for the current command.
func _tick_command(delta: float) -> Vector3:
	match command:
		Command.MOVE:
			if _flat_distance(_move_goal) <= _agent.target_desired_distance + 0.1:
				_set_command(Command.NONE, null)
				return Vector3.ZERO
			return _path_velocity(_move_goal)
		Command.ATTACK:
			if not _is_attackable(command_target):
				_set_command(Command.NONE, null)
				return Vector3.ZERO
			if _flat_distance(command_target.global_position) <= get_attack_range():
				_visual.face(command_target.global_position - global_position, delta)
				if _attack_cooldown_remaining <= 0.0:
					_perform_attack(command_target)
				return Vector3.ZERO
			_repath_timer -= delta
			if _repath_timer <= 0.0:
				_repath_timer = REPATH_SECONDS
				_agent.target_position = command_target.global_position
			return _path_velocity(command_target.global_position)
		Command.GATHER:
			var node: ResourceNode = command_target as ResourceNode
			if node == null or not is_instance_valid(node) or not node.is_gatherable:
				_set_command(Command.NONE, null)
				return Vector3.ZERO
			if _flat_distance(node.global_position) <= GATHER_REACH + _node_radius(node):
				_set_command(Command.NONE, null)
				_begin_gather_on(node)
				return Vector3.ZERO
			return _path_velocity(node.global_position)
		Command.CAMPFIRE:
			if command_target == null or not is_instance_valid(command_target):
				_set_command(Command.NONE, null)
				return Vector3.ZERO
			if _flat_distance(command_target.global_position) <= CAMPFIRE_REACH + _node_radius(command_target) * 0.5:
				_set_command(Command.NONE, null)
				var panel: Node = get_tree().get_first_node_in_group("crafting_panel")
				if panel != null:
					panel.open()
				return Vector3.ZERO
			return _path_velocity(command_target.global_position)
		Command.REPAIR:
			if not Repair.needs_repair(command_target):
				_set_command(Command.NONE, null)
				return Vector3.ZERO
			if _flat_distance(command_target.global_position) <= REPAIR_REACH + _node_radius(command_target):
				_visual.face(command_target.global_position - global_position, delta)
				_tool_busy = true
				_repair_timer -= delta
				if _repair_timer <= 0.0:
					_repair_timer = Repair.TAP_SECONDS
					if Repair.tap(command_target, self):
						_build_beat.swing(_visual)
					else:
						Fx.icon_popup(self, Fx.icon("wood"), "", Color.WHITE, true)
						_set_command(Command.NONE, null)
				return Vector3.ZERO
			return _path_velocity(command_target.global_position)
		Command.BUILD:
			var site: Building = command_target as Building if is_instance_valid(command_target) else null
			if site == null or site.is_queued_for_deletion() or not site.is_blueprint():
				_set_command(Command.NONE, null)
				return Vector3.ZERO
			if site.distance_to_footprint(global_position) <= BUILD_REACH:
				_tool_busy = true
				if _build_beat.tick(delta, _visual, site):
					_visual.face_instantly(site.global_position - global_position)
				if site.add_build_progress(delta, self):
					_set_command(Command.NONE, null)
					_build_beat.stop(_visual)
					_visual.play_action(&"cheer", 1.2)
				return Vector3.ZERO
			return _path_velocity(site.global_position)
	return Vector3.ZERO


## Velocity toward `goal`, following the nav path when one exists.
func _path_velocity(goal: Vector3) -> Vector3:
	return NavSteer.velocity(_agent, self, goal, move_speed)


func _keyboard_direction() -> Vector2:
	return Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)


func _set_command(new_command: int, target: Node3D) -> void:
	if new_command == command and target == command_target:
		return
	command = new_command
	command_target = target
	command_changed.emit(command, target)


## Build mode no longer blocks commands (the pointer and keys are off in
## it anyway), so the hero can go and build while the player places.
func _can_command() -> bool:
	return not is_down()


func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _node_radius(node: Node3D) -> float:
	var shape: CollisionShape3D = node.get_node_or_null("Collision") as CollisionShape3D
	if shape != null and shape.shape is CylinderShape3D:
		return (shape.shape as CylinderShape3D).radius
	if shape != null and shape.shape is SphereShape3D:
		return (shape.shape as SphereShape3D).radius
	if shape != null and shape.shape is BoxShape3D:
		var box: Vector3 = (shape.shape as BoxShape3D).size
		return maxf(box.x, box.z) * 0.5
	return 0.4


## Untyped: auto-attack can leave a freed mob here, which a typed
## argument would reject.
func _is_attackable(target: Variant) -> bool:
	return is_instance_valid(target) and (target as Node).is_in_group("mobs")


# --- Actions ---------------------------------------------------------------

func _perform_attack(target: Node3D) -> void:
	_attack_cooldown_remaining = attack_cooldown_seconds
	_visual.play_action(&"attack", 1.5)
	attacked.emit(target)
	if hero != null and hero.ranged:
		PebbleShot.fire(self, target, attack_damage)
		return
	var tween: Tween = create_tween()
	tween.tween_interval(ATTACK_WINDUP)
	tween.tween_callback(func() -> void:
		if _is_attackable(target) and _flat_distance(target.global_position) <= get_attack_range() * 1.4:
			# Big Swing: the swing carries on to the next mob.
			var extra: Array[Node3D] = HeroHits.extra_targets(self, target, &"melee")
			HeroHits.strike(self, target, attack_damage)
			Fx.burst(&"hit", target.global_position + Vector3(0, 0.7, 0))
			for other in extra:
				HeroHits.strike(self, other, attack_damage)
				Fx.burst(&"hit", other.global_position + Vector3(0, 0.7, 0))
			Fx.hit_stop()
	)


## E next to the Moon Lantern hands over the stash's Glow Shards
## (feature 036). False when there is nothing to hand over here.
func try_feed_lantern() -> bool:
	var lantern: MoonLantern = MoonLantern.find(get_tree())
	if lantern == null or not lantern.in_reach(global_position) or not lantern.can_accept():
		return false
	_cancel_active_gather()
	_visual.face_instantly(lantern.global_position - global_position)
	lantern.deliver(self)
	return true


func _try_begin_gather() -> void:
	if _state == PlayerState.GATHERING or _interactor == null:
		return
	var node: ResourceNode = _interactor.get_closest()
	if node == null:
		return
	_set_command(Command.NONE, null)
	_begin_gather_on(node)


func _begin_gather_on(node: ResourceNode) -> void:
	if not node.begin_gather(self):
		return
	_active_node = node
	if not node.gathered.is_connected(_on_node_gathered):
		node.gathered.connect(_on_node_gathered)
	_state = PlayerState.GATHERING
	velocity = Vector3.ZERO
	_visual.face_instantly(node.global_position - global_position)
	_visual.play_action(node.gather_animation, 1.5)


func _cancel_active_gather() -> void:
	if _active_node != null:
		if is_instance_valid(_active_node):
			if _active_node.gathered.is_connected(_on_node_gathered):
				_active_node.gathered.disconnect(_on_node_gathered)
			_active_node.cancel_gather(self)
		_active_node = null
	if _state == PlayerState.GATHERING:
		_state = PlayerState.IDLE


func _on_node_gathered(actor: Node, _id: StringName, _amount: int) -> void:
	if actor != self:
		return
	if _active_node != null and _active_node.gathered.is_connected(_on_node_gathered):
		_active_node.gathered.disconnect(_on_node_gathered)
	_active_node = null
	_state = PlayerState.IDLE


func _on_interactor_exited(node: ResourceNode) -> void:
	if node == _active_node:
		_cancel_active_gather()


## Space: swing at the nearest imp in range (keyboard shortcut).
func _try_attack() -> void:
	if _state == PlayerState.GATHERING or _attack_cooldown_remaining > 0.0:
		return
	var target: Node3D = _find_nearest_mob_in_range()
	if target == null:
		# Swing anyway so the key feels responsive.
		_attack_cooldown_remaining = attack_cooldown_seconds
		_visual.play_action(&"attack", 1.5)
		return
	_visual.face_instantly(target.global_position - global_position)
	command_attack(target)


func _try_place_torch() -> void:
	if _state == PlayerState.GATHERING:
		return
	if not ResourceManager.spend(TORCH_ITEM_ID, 1):
		Fx.icon_popup(self, Fx.icon("torch"), "", Color.WHITE, true)
		return
	var torch: Node3D = TORCH_SCENE.instantiate() as Node3D
	get_tree().current_scene.add_child(torch)
	torch.global_position = global_position + get_facing() * 1.0
	if torch.has_method("kindle"):
		torch.call("kindle", self)
	Fx.burst(&"dust", torch.global_position)
	GameManager.record(&"torches_placed")
	PlaytestLog.write("torch_placed day=%d phase=%s" % [TimeManager.day_number, TimeManager.get_phase_name()])


## R: eat a Berry Snack if there is one (+35 HP), else 2 berries (+15).
func _try_eat_berries() -> void:
	if current_hp >= max_hp:
		Fx.icon_popup(self, Fx.icon("snack" if ResourceManager.has(SNACK_ITEM_ID, 1) else "berries"), "", Color.WHITE, true)
		return
	var amount: int = heal_per_meal
	if ResourceManager.spend(SNACK_ITEM_ID, 1):
		amount = roundi(heal_per_snack * PerkManager.multiplier(self, &"snack_heal"))
	elif not ResourceManager.spend(BERRY_ITEM_ID, BERRIES_PER_MEAL):
		Fx.icon_popup(self, Fx.icon("berries"), "", Color.WHITE, true)
		return
	heal(amount)
	Fx.float_text(self, "+%d HP" % amount, Color(0.5, 1, 0.5))
	Fx.burst(&"heal", global_position)


## The hero's signature upgrade: Sturdy Stick (more damage) or
## Slingshot (more reach), for the rest of the run.
func apply_signature() -> void:
	if has_signature or hero == null:
		return
	has_signature = true
	attack_damage += hero.signature_damage_bonus
	attack_range *= hero.signature_range_factor
	Fx.float_text(self, "%s!" % hero.signature_label.to_upper(), Color(1.0, 0.85, 0.4), 2.8)
	Fx.burst(&"level_up", global_position)


## X: bandage the companion when they are close and hurt (or knocked out).
func try_use_bandage() -> bool:
	var sibling: Node3D = get_tree().get_first_node_in_group("companions") as Node3D
	var close: bool = sibling != null and _flat_distance(sibling.global_position) <= BANDAGE_REACH
	if not close or not ResourceManager.has(BANDAGE_ITEM_ID, 1) or not sibling.has_method("apply_bandage"):
		Fx.icon_popup(self, Fx.icon("bandage"), "", Color.WHITE, true)
		return false
	if not sibling.apply_bandage():
		Fx.icon_popup(self, Fx.icon("bandage"), "", Color.WHITE, true)
		return false
	ResourceManager.spend(BANDAGE_ITEM_ID, 1)
	return true


func _on_level_up(character: Node, _new_level: int) -> void:
	if character != self or stats == null:
		return
	attack_damage += stats.attack_damage_per_level
	_hp_bar.set_level(_new_level)
	max_hp += stats.max_health_per_level
	current_hp = min(max_hp, current_hp + stats.max_health_per_level)
	health_changed.emit(current_hp, max_hp)
	if not ProgressionManager.is_restoring:
		# The perk picker (opened first, by PerkManager) says it itself.
		if not PerkManager.is_picking():
			Fx.float_text(self, "LEVEL UP!", Color(1.0, 0.85, 0.4), 2.8)
		Fx.burst(&"level_up", global_position)


## Auto-attack and auto-build (feature 044): only when the player gave
## no command (or the hero is gathering), never while walking by hand.
## Fighting comes first, then the interrupted gather, then blueprints.
func _tick_auto() -> void:
	if not _can_command() or _keyboard_direction().length() > 0.0:
		return
	if command != Command.NONE:
		return
	var target: Node3D = _find_nearest_mob_in_range(auto_attack_radius()) if auto_attack else null
	if target != null:
		var interrupted: ResourceNode = _active_node if _state == PlayerState.GATHERING else _resume_node
		command_attack(target)
		_resume_node = interrupted
	elif _resume_node != null:
		var node: ResourceNode = _resume_node
		_resume_node = null
		if is_instance_valid(node) and node.is_gatherable:
			command_gather(node)
	elif _state != PlayerState.GATHERING:
		var site: Building = BuildManager.next_blueprint()
		if site != null:
			command_build(site)


func _find_nearest_mob_in_range(radius: float = -1.0) -> Node3D:
	var best: Node3D = null
	if radius < 0.0:
		radius = get_attack_range() * 1.2
	var best_d_sq: float = radius * radius
	for node in get_tree().get_nodes_in_group("mobs"):
		var n3d: Node3D = node as Node3D
		if n3d == null or not is_instance_valid(n3d):
			continue
		var d_sq: float = n3d.global_position.distance_squared_to(global_position)
		if d_sq < best_d_sq:
			best_d_sq = d_sq
			best = n3d
	return best
