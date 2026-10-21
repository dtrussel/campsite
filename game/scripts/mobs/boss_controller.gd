class_name BossController
extends Mob

## BossController
##
## The Moon-Eater (feature 038, docs/design/story.md): the final night
## of Chapter 2. A huge, sad golem of planks and stones that swallowed
## the moon's light. It is never killed, only calmed: at 0 HP it lets
## the moon go and shrinks into a small warm golem by the fire, and the
## night ends.
##
## Phases (by HP):
##   1. It walks to the campfire with a telegraphed **stomp** (a ring on
##      the ground) and **sweep** (a slice in front of it).
##   2. Below `phase_2_at` it also **summons** imp packs from the lanes
##      every `summon_interval` seconds and puts out the torches.
##   3. Below `phase_3_at` it walks to the Moon Lantern and **reaches**
##      for its light. The lantern stage decides how long the kids have
##      (`reach_seconds`); the light burns it meanwhile. If the time
##      runs out it swallows two stages, heals to `reach_heal_to` and
##      goes back to phase 2. A dark lantern has nothing to eat, so it
##      fights on to the end.
## While it stands, the night does not end (TimeManager.hold_night).
## Snap traps can't hold it. The model is MoonEaterVisual, a code-built
## stand-in until the team's art arrives.

signal phase_changed(phase: int)
signal health_changed(current_hp: int, max_hp: int)
## Its HP reached 0: it lets the moon go (the shrink ending starts).
signal calmed(boss: Node3D)

enum Phase { RISING, STOMPING, SUMMONING, REACHING, CALMED }

const GROUP: StringName = &"boss"
## Where the small warm golem curls up, next to the campfire.
const CURL_UP_OFFSET: Vector3 = Vector3(-2.0, 0.0, 0.3)

@export_group("Phases")
@export_range(0.0, 1.0) var phase_2_at: float = 0.6
@export_range(0.0, 1.0) var phase_3_at: float = 0.25
## Seconds it staggers when a new phase starts (an opening for the kids).
@export var stagger_seconds: float = 1.2
@export_group("Stomp")
@export var stomp_windup: float = 0.9
@export var stomp_radius: float = 3.2
## How far in front of it the fists land.
@export var stomp_reach: float = 1.4
@export var campfire_damage: int = 6
@export_group("Sweep")
@export var sweep_windup: float = 0.8
@export var sweep_range: float = 5.0
@export var sweep_arc: float = 140.0
@export var sweep_damage: int = 7
@export_group("Summon")
@export var summon_interval: float = 16.0
@export var summon_pack: int = 3
@export var summon_definition: MobDefinition
@export_group("Reach")
## Seconds the kids have once it holds the lantern: base + per stage.
@export var reach_base_seconds: float = 6.0
@export var reach_seconds_per_stage: float = 3.0
## It curls round the lantern: hits do this much of their damage.
@export_range(0.0, 1.0) var reach_damage_factor: float = 0.5
## Lantern burn per lit stage, every lantern light interval.
@export var reach_burn_per_stage: int = 2
@export var reach_steal_stages: int = 2
@export_range(0.0, 1.0) var reach_heal_to: float = 0.45
@export var lantern_reach: float = 2.6
@export_group("")

var phase: int = Phase.RISING

var _look: MoonEaterVisual = null
var _busy: float = 0.0
var _stagger: float = 0.0
var _summon_in: float = 0.0
var _next_is_sweep: bool = false
var _draining: bool = false
var _reach_left: float = 0.0
var _reach_total: float = 1.0
var _burn_tick: float = 0.0
## Set once a reach found the lantern dark: it fights on to the end.
var _reach_done: bool = false
var _held_night: bool = false


static func find(tree: SceneTree) -> BossController:
	return tree.get_first_node_in_group(GROUP) as BossController if tree != null else null


func _ready() -> void:
	super._ready()
	add_to_group(GROUP)
	_look = get_node_or_null("Visual") as MoonEaterVisual
	# The HUD's boss bar shows its health instead of an overhead bar.
	if _hp_bar != null:
		_hp_bar.visible = false
	_spawn_remaining = _look.play_action(&"rise") if _look != null else 2.0
	TimeManager.hold_night = true
	_held_night = true
	AudioManager.set_mood(&"boss")
	PlaytestLog.write("boss_rises hp=%d day=%d" % [current_hp, TimeManager.day_number])
	_face_camp.call_deferred()


func _face_camp() -> void:
	if _look != null and _base != null:
		_look.face_instantly(_base.global_position - global_position)


func _exit_tree() -> void:
	if _held_night:
		TimeManager.hold_night = false
		_held_night = false


func hp_ratio() -> float:
	return float(current_hp) / float(maxi(1, max_hp()))


func is_draining() -> bool:
	return _draining


## How much of the reach window is left (1 = all, 0 = none).
func reach_left_ratio() -> float:
	return clampf(_reach_left / maxf(_reach_total, 0.01), 0.0, 1.0)


## The seconds a reach lasts for a lantern at `stage`.
func reach_seconds(stage: int) -> float:
	return reach_base_seconds + reach_seconds_per_stage * stage


## Too big for a snap trap.
func stun(_seconds: float) -> void:
	pass


func take_damage(amount: int, source: Node = null) -> void:
	if state == State.DYING or phase == Phase.CALMED:
		return
	if _draining and source != null:
		amount = maxi(1, int(round(amount * reach_damage_factor)))
	super.take_damage(amount, source)
	health_changed.emit(current_hp, max_hp())
	if current_hp > 0:
		_check_phase()


# --- AI ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == State.DYING or definition == null:
		return
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	_busy = maxf(0.0, _busy - delta)
	if _spawn_remaining > 0.0:
		_spawn_remaining -= delta
		if _spawn_remaining <= 0.0:
			_enter(Phase.STOMPING)
		return
	if _base == null or not is_instance_valid(_base):
		_refresh_base()
	if _stagger > 0.0:
		_stagger -= delta
		_stand()
		return
	if phase == Phase.REACHING:
		_tick_reach(delta)
		return
	if phase == Phase.SUMMONING:
		_summon_in -= delta
		if _summon_in <= 0.0 and _busy <= 0.0:
			summon()
			return
	_tick_fight(delta)


func _tick_fight(delta: float) -> void:
	if _busy > 0.0:
		_stand()
		return
	_update_chase_target()
	var target: Node3D = _chase_target if _chase_target != null else _base
	if target == null:
		_stand()
		return
	var to_target: Vector3 = _flat_to(target.global_position)
	var distance: float = to_target.length()
	var at_fire: bool = target == _base and distance <= stomp_reach + stomp_radius * 0.6 + CAMPFIRE_REACH_BONUS
	var blocker: Node = _find_blocker()
	if _attack_cooldown_remaining <= 0.0 and (at_fire or blocker != null or (_chase_target != null and distance <= sweep_range * 0.9)):
		if _look != null:
			_look.face_instantly(to_target)
		# Close kids and the fire get the stomp; kids further off, the
		# sweep. It mixes them up when both would reach.
		var sweep: bool = _chase_target != null and (distance > stomp_reach + stomp_radius * 0.7 or _next_is_sweep)
		if sweep:
			sweep_attack()
		else:
			stomp()
		_next_is_sweep = not sweep
		return
	if at_fire:
		_stand()
		return
	_walk(to_target, delta)


func _walk(to_target: Vector3, delta: float) -> void:
	var speed: float = definition.move_speed * _torch_slow_factor()
	velocity = to_target.normalized() * speed if to_target.length() > 0.05 else Vector3.ZERO
	move_and_slide()
	if _look != null:
		_look.set_locomotion(speed)
		_look.face(to_target, delta)


func _stand() -> void:
	velocity = Vector3.ZERO
	if _look != null:
		_look.set_locomotion(0.0)


func _check_phase() -> void:
	var ratio: float = hp_ratio()
	if phase == Phase.STOMPING and ratio <= phase_2_at:
		_enter(Phase.SUMMONING)
	if phase == Phase.SUMMONING and ratio <= phase_3_at and not _reach_done:
		var lantern: MoonLantern = MoonLantern.find(get_tree())
		if lantern != null and lantern.stage > 0:
			_enter(Phase.REACHING)
		else:
			_reach_done = true


func _enter(next: int) -> void:
	phase = next
	match next:
		Phase.SUMMONING:
			_stagger_now()
			_summon_in = stagger_seconds + 0.2
		Phase.REACHING:
			_stagger_now()
			_draining = false
	PlaytestLog.write("boss_phase phase=%d hp=%d" % [phase, current_hp])
	phase_changed.emit(phase)


func _stagger_now() -> void:
	_stagger = stagger_seconds
	_busy = 0.0
	if _look != null:
		_look.play_action(&"stagger")


# --- Attacks -----------------------------------------------------------------

func _forward() -> Vector3:
	var yaw: float = _look.rotation.y if _look != null else rotation.y
	return Vector3(sin(yaw), 0.0, cos(yaw))


## Both fists down on a ring in front of it, after `stomp_windup`.
func stomp() -> void:
	var center: Vector3 = global_position + _forward() * stomp_reach
	Telegraph.show_at(get_parent(), center, stomp_radius, stomp_windup)
	_busy = _look.play_action(&"stomp", stomp_windup) if _look != null else stomp_windup + 1.0
	_attack_cooldown_remaining = definition.attack_cooldown_seconds
	get_tree().create_timer(stomp_windup, false).timeout.connect(_land_stomp.bind(center))


func _land_stomp(center: Vector3) -> void:
	if state == State.DYING:
		return
	Fx.burst(&"moon_eater_stomp", center)
	Fx.shake(0.55)
	_hit_area(center, 0.0, stomp_radius, 360.0, definition.attack_damage)


## One arm across a slice in front of it, after `sweep_windup`.
func sweep_attack() -> void:
	var yaw: float = _look.rotation.y if _look != null else rotation.y
	Telegraph.show_at(get_parent(), global_position, sweep_range, sweep_windup, sweep_arc, yaw)
	_busy = _look.play_action(&"sweep", sweep_windup) if _look != null else sweep_windup + 1.0
	_attack_cooldown_remaining = definition.attack_cooldown_seconds
	get_tree().create_timer(sweep_windup, false).timeout.connect(_land_sweep.bind(global_position, yaw))


func _land_sweep(center: Vector3, yaw: float) -> void:
	if state == State.DYING:
		return
	Fx.burst(&"moon_eater_sweep", center + Vector3(sin(yaw), 0.0, cos(yaw)) * sweep_range * 0.6)
	Fx.shake(0.3)
	_hit_area(center, yaw, sweep_range, sweep_arc, sweep_damage)


## Hits every kid, building and the campfire inside the area. Kids who
## stepped out during the windup are safe; that is the point.
func _hit_area(center: Vector3, yaw: float, area_radius: float, arc: float, damage: int) -> void:
	var hit: int = 0
	for group in [&"player", &"companions"]:
		for node in get_tree().get_nodes_in_group(group):
			var kid: Node3D = node as Node3D
			if kid == null or not _is_valid_character(kid):
				continue
			if Telegraph.in_area(center, yaw, area_radius, arc, kid.global_position):
				kid.call("take_damage", damage, self)
				hit += 1
			else:
				PlaytestLog.write("attack_dodged mob=%s" % definition.id)
	for node in get_tree().get_nodes_in_group(Repair.GROUP):
		var building: Building = node as Building
		if building == null or building.current_hp <= 0 or building.collision_layer == 0:
			continue
		if Telegraph.in_area(center, yaw, area_radius + _footprint_radius(building), arc, building.global_position):
			building.take_damage(int(round(damage * definition.building_damage_multiplier)), self)
	if _base != null and is_instance_valid(_base) and Telegraph.in_area(center, yaw, area_radius + CAMPFIRE_REACH_BONUS, arc, _base.global_position):
		_base.call("take_damage", campfire_damage, self)


## Calls an imp pack from the lanes (never past the spawner's mob cap)
## and puts out the torches. Returns how many came.
func summon() -> int:
	_summon_in = summon_interval
	_busy = _look.play_action(&"summon") if _look != null else 1.8
	Fx.burst(&"moon_eater_summon", global_position + Vector3(0, 3.0, 0))
	var snuffed: int = 0
	for node in get_tree().get_nodes_in_group(TORCH_GROUP):
		if node.has_method("snuff") and bool(node.get("burns_out_at_dawn")):
			node.call("snuff")
			snuffed += 1
	var spawner: MobSpawner = get_tree().get_first_node_in_group("mob_spawner") as MobSpawner
	var came: int = 0
	if spawner != null and summon_definition != null:
		came = spawner.summon(summon_definition, summon_pack)
	PlaytestLog.write("boss_summon imps=%d torches_out=%d" % [came, snuffed])
	return came


# --- Phase 3: the reach ------------------------------------------------------

func _tick_reach(delta: float) -> void:
	var lantern: MoonLantern = MoonLantern.find(get_tree())
	if lantern == null:
		_reach_done = true
		phase = Phase.SUMMONING
		return
	var to_lantern: Vector3 = _flat_to(lantern.global_position)
	if not _draining:
		if _busy > 0.0:
			_stand()
		elif to_lantern.length() > lantern_reach:
			_walk(to_lantern, delta)
		else:
			_start_drain(lantern)
		return
	_stand()
	_reach_left -= delta
	lantern.set_drain(1.0 - reach_left_ratio())
	_burn_tick += delta
	if _burn_tick >= lantern.light_interval_seconds:
		_burn_tick = 0.0
		take_damage(reach_burn_per_stage * lantern.stage, null)
		Fx.burst(&"shard", global_position + Vector3(0, 2.0, 0) + _forward() * 1.2)
	if state != State.DYING and phase == Phase.REACHING and _reach_left <= 0.0:
		_swallow(lantern)


func _start_drain(lantern: MoonLantern) -> void:
	_draining = true
	_reach_total = reach_seconds(lantern.stage)
	_reach_left = _reach_total
	_burn_tick = 0.0
	if _look != null:
		_look.face_instantly(lantern.global_position - global_position)
		_look.play_action(&"reach")
	PlaytestLog.write("boss_reach seconds=%.1f stage=%d hp=%d" % [_reach_total, lantern.stage, current_hp])
	phase_changed.emit(phase)


## Time ran out: it gulps two stages of the lantern's light and comes
## back stronger.
func _swallow(lantern: MoonLantern) -> void:
	_draining = false
	lantern.set_drain(0.0)
	var lost: int = lantern.lose_stages(reach_steal_stages)
	current_hp = maxi(current_hp, int(round(max_hp() * reach_heal_to)))
	health_changed.emit(current_hp, max_hp())
	Fx.burst(&"moon_eater_summon", lantern.global_position + Vector3(0, 1.8, 0))
	PlaytestLog.write("boss_swallowed stages=%d hp=%d" % [lost, current_hp])
	if _look != null:
		_look.play_action(&"idle")
	phase = Phase.SUMMONING
	_summon_in = 3.0
	phase_changed.emit(phase)


# --- The ending ----------------------------------------------------------------

## Never killed: at 0 HP it lets the moon go and shrinks into a small
## warm golem by the fire. `defeated` fires once that is done, so the
## spawner ends the night and the run is won at dawn.
func _die() -> void:
	state = State.DYING
	phase = Phase.CALMED
	_draining = false
	remove_from_group("mobs")
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	_award_kill_xp()
	GameManager.record(&"boss_calmed")
	var lantern: MoonLantern = MoonLantern.find(get_tree())
	if lantern != null:
		lantern.set_drain(0.0)
	PlaytestLog.write("boss_calmed day=%d" % TimeManager.day_number)
	phase_changed.emit(phase)
	calmed.emit(self)
	AudioManager.set_mood(&"")
	# The moonlight streams out of it and every other shadow fades.
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob: Mob = node as Mob
		if mob != null and mob != self:
			mob.take_damage(9999, null)
	Fx.burst(&"moon_eater_sigh", global_position + Vector3(0, 2.0, 1.2))
	_moonbeam()
	var seconds: float = _look.play_final(&"shrink") if _look != null else 0.5
	await get_tree().create_timer(seconds, false).timeout
	await _curl_up_by_fire()
	if _held_night:
		TimeManager.hold_night = false
		_held_night = false
	defeated.emit(self)


## The small warm golem pads over to the campfire and curls up.
func _curl_up_by_fire() -> void:
	if _base == null or not is_instance_valid(_base):
		return
	var spot: Vector3 = _base.global_position + CURL_UP_OFFSET
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", spot, 2.0).set_trans(Tween.TRANS_SINE)
	if _look != null:
		_look.face_instantly(spot - global_position)
		_look.set_locomotion(0.8)
	await tween.finished
	if _look != null:
		_look.set_locomotion(0.0)
		_look.face_instantly(_base.global_position - global_position)
		if _look.little_golem() != null:
			_look.little_golem().curl_up()


## A column of moonlight rising out of its belly into the sky.
func _moonbeam() -> void:
	var beam: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.9
	cylinder.bottom_radius = 0.5
	cylinder.height = 30.0
	beam.mesh = cylinder
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(UiKit.COLOR_MOON, 0.0)
	beam.material_override = material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(beam)
	beam.global_position = global_position + _forward() * 0.9 + Vector3(0, 16.0, 0)
	var tween: Tween = beam.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.5, 0.8)
	tween.tween_interval(1.6)
	tween.tween_property(material, "albedo_color:a", 0.0, 1.6)
	tween.tween_callback(beam.queue_free)
