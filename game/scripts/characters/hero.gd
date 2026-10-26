class_name Hero
extends CharacterBody3D

## Hero
##
## Everything Leo or Nela does whichever role they play.
## The two role scripts extend it and add only what differs:
## - the player's hero (`player_controller.gd`): input, pointer commands
##   and the hit feel. Being down ends the run (GameManager listens).
## - the companion (`Companion`): the task AI and the stuck watchdog.
##   Being down lasts until dawn.
##
## Outside code talks to a hero through this interface only: never read
## a role's private fields by name.
##
## The script is split into sections, one per part of the hero:
## Health, Attack, Progress, Gathering with the shared queries, and Look.

## HP changed (a hit, a heal, regen, a level-up or a revive).
signal health_changed(current_hp: int, max_hp: int)
## The hero went down at 0 HP (true) or got back up (false).
signal down_changed(is_down: bool)

## The hero played in this role; each role fills an empty one from the
## party in `_enter_tree`.
@export var hero: HeroDefinition
@export var stats: CharacterStatsDefinition

@onready var _visual: CharacterVisual = $Visual


# --- Health --------------------------------------------------------------
# Hits, heals, regen, the invulnerability window and being down. The
# role decides what being down means (`_on_down_changed`) and how a hit
# looks and sounds (`_show_hurt`).

## Overwritten by the stats' base health. The role sets its own default.
@export var max_hp: int = 50
## HP regained per second outside the night.
@export var regen_per_second: float = 1.2
## After a hit, further hits are ignored this long, so a crowd of mobs
## cannot delete a hero in one frame.
@export var hurt_invulnerability_seconds: float = 0.6

var current_hp: int = 0
var _down: bool = false
## The bar over the head; the role attaches it in `_ready`.
var _hp_bar: HealthBar3D = null
var _invulnerable_remaining: float = 0.0
var _regen_accumulator: float = 0.0


## True from reaching 0 HP until `revive`.
func is_down() -> bool:
	return _down


## True while the window after a hit ignores further hits.
func is_invulnerable() -> bool:
	return _invulnerable_remaining > 0.0


## The health bar over the hero's head (null before `_ready`).
func health_bar() -> HealthBar3D:
	return _hp_bar


## Ends the invulnerability window now (tests and scripted hits).
func clear_invulnerability() -> void:
	_invulnerable_remaining = 0.0


## Mobs call this. Damage-taken perks (Stand Firm) apply here, in both
## roles. Ignored while down or inside the invulnerability window.
func take_damage(amount: int, _source: Node = null) -> void:
	if amount <= 0 or _down or _invulnerable_remaining > 0.0:
		return
	_invulnerable_remaining = hurt_invulnerability_seconds
	amount = HeroHits.damage_taken(self, amount)
	current_hp = maxi(0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)
	_show_hurt(amount)
	if current_hp == 0:
		_set_down(true)
	elif not _visual.is_in_action():
		_visual.play_action(&"hit", hero.hit_play_speed if hero != null else 1.0)


## Heals `amount` HP, up to max. Not while down.
func heal(amount: int) -> void:
	if amount <= 0 or _down or current_hp >= max_hp:
		return
	current_hp = mini(max_hp, current_hp + amount)
	health_changed.emit(current_hp, max_hp)


## Gets a downed hero back up with `hp` HP (at least 1, at most max).
func revive(hp: int) -> void:
	if not _down:
		return
	current_hp = clampi(hp, 1, max_hp)
	_set_down(false)
	health_changed.emit(current_hp, max_hp)


## The role calls this every physics frame: it runs the invulnerability
## window and regen (none at night or while down).
func _tick_health(delta: float) -> void:
	_invulnerable_remaining = maxf(0.0, _invulnerable_remaining - delta)
	if _down or TimeManager.is_night() or current_hp >= max_hp:
		_regen_accumulator = 0.0
		return
	_regen_accumulator += regen_per_second * delta
	if _regen_accumulator >= 1.0:
		var whole: int = int(_regen_accumulator)
		_regen_accumulator -= whole
		heal(whole)


## The role calls this once in `_ready`: a hero health bar at `height`,
## kept in step with `health_changed`.
func _attach_health_bar(height: float, width: float) -> void:
	_hp_bar = HealthBar3D.attach(self, height, "hero", width)
	health_changed.connect(func(hp: int, max_value: int) -> void: _hp_bar.set_value(hp, max_value))
	_hp_bar.set_value.call_deferred(current_hp, max_hp)


func _set_down(value: bool) -> void:
	if _down == value:
		return
	_down = value
	if value:
		velocity = Vector3.ZERO
		_cancel_wind_up()
		_visual.play_final(&"death")
	else:
		_visual.unlock(&"getup")
	_on_down_changed(value)
	down_changed.emit(value)


## Role hook: the hit's feedback (flash, number, sound).
func _show_hurt(_amount: int) -> void:
	pass


## Role hook: what going down (or back up) means for this role, run
## before `down_changed` is emitted.
func _on_down_changed(_is_down: bool) -> void:
	pass


# --- Attack --------------------------------------------------------------
# Attacking a target, reach, readiness, damage and the signature tool's
# tiers: their bonuses, the burn and the night light.
# The module owns the cooldown and the melee vs pebble branch; HeroHits
# stays the perk math underneath (every hit goes through its strike()).
# The role adds the feel: `_show_attack` (the swing animation) and
# `_swing` (the player's hit puff, the companion's sparkle).
# Every hit that lands hit-stops the hero's visual and the target's
# (`on_attack_hit`); the game itself never slows for it.
# The hit lands on the attack clip's contact frame (the definition's
# `attack_contact_time`, as the visual reports it), after a short wind-up;
# a hero without one hits the moment the attack starts.
# Settled: the signature's float text lasts 2.8 s in both roles (the
# companion's was 2.7 s).

## An attack at `target` started (the swing or the pebble follows at the
## contact frame).
signal attacked(target: Node3D)

## Damage per hit before perks. Set from the stats' base attack; level-
## ups and the signature tool add to it.
@export var attack_damage: int = 4
## Reach before perks, from the definition by role (`_read_attack_tuning`).
## Read `get_attack_range()` wherever the reach matters.
@export var attack_range: float = 2.0
## Seconds between attacks, from the definition by role.
@export var attack_cooldown_seconds: float = 0.65

## The tier of the hero's signature tool (0: none yet), made at the
## Crafting Table one tier at a time, per run. Read-only outside: raise
## it with `set_tool_tier`. Save and crafting read it by name.
var tool_tier: int = 0
## True once the hero owns tier 1 of their signature tool (Leo's Sturdy
## Stick, Nela's Slingshot).
var has_signature: bool:
	get:
		return tool_tier > 0

## The small personal light an owned `night_light` tier gives at night.
var _tool_light: OmniLight3D = null

var _attack_cooldown_remaining: float = 0.0
## Pebbles shot this run, for the Double Sling's every-third double.
var _shot_count: int = 0
## What the last attack was aimed at (for `is_attacking`).
var _attack_target: Node3D = null
## The wind-up to the contact frame of the attack in flight (null: none).
var _wind_up: Tween = null


## Attacks `target` now: starts the cooldown and the attack animation,
## then at its contact frame fires a pebble (a ranged hero) or swings
## (melee). It does not wait for the cooldown: callers check
## `is_attack_ready()` first. False if the hero is down or `target`
## cannot be hit.
func attack(target: Node3D) -> bool:
	if _down or target == null or not is_instance_valid(target) or not target.has_method("take_damage"):
		return false
	_attack_cooldown_remaining = attack_cooldown_seconds
	_attack_target = target
	_cancel_wind_up()
	_show_attack(target)
	attacked.emit(target)
	var wind_up: float = _visual.action_contact_in()
	if wind_up <= 0.0:
		_on_contact_frame(target)
		return true
	_wind_up = create_tween()
	_wind_up.tween_interval(wind_up)
	_wind_up.tween_callback(_on_contact_frame.bind(target))
	return true


## The attack's contact frame: the pebble flies toward where the target
## is now, or the swing lands if the target is still there and in reach
## (else it misses quietly).
func _on_contact_frame(target: Node3D) -> void:
	_wind_up = null
	if _down or not is_instance_valid(target) or (target.has_method("is_alive") and not target.call("is_alive")):
		return
	if hero != null and hero.ranged:
		_shoot(target)
		return
	var slack: float = hero.contact_reach_slack if hero != null else 1.0
	if _flat_distance(target.global_position) <= get_attack_range() * slack:
		_swing(target)


## Drops the attack in its wind-up, if any (going down, a reset).
func _cancel_wind_up() -> void:
	if _wind_up != null and _wind_up.is_valid():
		_wind_up.kill()
	_wind_up = null


## The attack clip's play speed in this role (the hero's data).
func _attack_anim_speed() -> float:
	return hero.attack_speed(_is_companion_role()) if hero != null else 1.0


## Fires a pebble at `target`; with the Double Sling every few shots
## fire a second one too (launched now, so it counts with its shot,
## and flying a moment after the first).
func _shoot(target: Node3D) -> void:
	_shot_count += 1
	var damage: int = get_attack_damage()
	PebbleShot.fire(self, target, damage)
	var double: ToolTier = tool_effect_tier(&"double_shot")
	if double != null and _shot_count % maxi(double.double_shot_every, 1) == 0:
		PebbleShot.fire(self, target, damage, double.double_shot_gap_seconds)


## The damage of one hit now, before per-target perks (Twin Strike).
func get_attack_damage() -> int:
	return attack_damage


## The reach of an attack now: `attack_range` after perks (Eagle Eye).
## Use this, not `attack_range`, wherever the reach matters.
func get_attack_range() -> float:
	return attack_range * PerkManager.multiplier(self, &"attack_range")


## True when the cooldown has run out and the hero is up.
func is_attack_ready() -> bool:
	return not _down and _attack_cooldown_remaining <= 0.0


## How much of the cooldown is left: 1 just after an attack, 0 when ready.
func get_attack_cooldown_ratio() -> float:
	return clampf(_attack_cooldown_remaining / maxf(attack_cooldown_seconds, 0.01), 0.0, 1.0)


## True while the hero is fighting: its last attack's cooldown is still
## running and the target is still there. The player's hero also counts
## an attack command (walking to the target included).
func is_attacking() -> bool:
	return _attack_cooldown_remaining > 0.0 and is_instance_valid(_attack_target)


## Gives the hero tier 1 of their signature tool (see `set_tool_tier`).
func apply_signature() -> void:
	set_tool_tier(1)


## Raises the signature tool to `tier`, adding each new tier's damage
## bonus and its range factor for this role (the companion reads
## `companion_range_factor`). A tier the hero already owns, or one past
## the hero's last, changes nothing. `quiet` skips the float text (a
## save being restored).
func set_tool_tier(tier: int, quiet: bool = false) -> void:
	if hero == null:
		return
	tier = mini(tier, hero.tier_count())
	if tier <= tool_tier:
		return
	for n in range(tool_tier + 1, tier + 1):
		var step: ToolTier = hero.tier(n)
		attack_damage += step.damage_bonus
		attack_range *= _range_factor_of(step)
	tool_tier = tier
	_update_tool_light()
	if not quiet:
		Fx.float_text(self, "%s!" % hero.tier(tier).label.to_upper(), Color(1.0, 0.85, 0.4), 2.8)
		Fx.burst(&"level_up", global_position)


## A tier's range factor for this role (the companion reads
## `companion_range_factor`).
func _range_factor_of(step: ToolTier) -> float:
	return step.companion_range_factor if _is_companion_role() else step.range_factor


## True if a tier the hero owns has `effect` (ToolTier.EFFECTS).
func has_tool_effect(effect: StringName) -> bool:
	return tool_effect_tier(effect) != null


## The highest tier the hero owns that has `effect`, whose numbers the
## effect uses; null when no owned tier has it.
func tool_effect_tier(effect: StringName) -> ToolTier:
	if hero == null:
		return null
	for n in range(tool_tier, 0, -1):
		if hero.tier(n).effects.has(effect):
			return hero.tier(n)
	return null


## The tier that `recipe_id` makes on this hero's tool path (1-based),
## or 0 if it is not one of this hero's tiers.
func tier_of_recipe(recipe_id: StringName) -> int:
	return hero.tier_of_recipe(recipe_id) if hero != null else 0


## How far the tool's night light reaches: further with a `bright_light`
## tier (the Blaze Stick); 0 without a light.
func get_tool_light_range() -> float:
	var light: ToolTier = tool_effect_tier(&"bright_light")
	if light == null:
		light = tool_effect_tier(&"night_light")
	return light.light_range if light != null else 0.0


## True while the Ember Stick's personal light is lit.
func is_tool_light_on() -> bool:
	return _tool_light != null and _tool_light.visible


## HeroHits.strike calls this for every hit the hero lands (a swing, a
## Big Swing extra, a pebble, a Ricochet bounce), after the damage: the
## hit-stop on the hero and the target (which squashes), and the tool's
## on-hit effects (the Ember Stick's burn, the Blaze Stick's splash onto
## the mobs beside the target, and the Glow Sling's glow).
func on_attack_hit(target: Node, _damage: int) -> void:
	_visual.hit_stop()
	var target_visual: CharacterVisual = target.get_node_or_null("Visual") as CharacterVisual
	if target_visual != null:
		target_visual.hit_stop(true)
	var glow: ToolTier = tool_effect_tier(&"glow_hit")
	if glow != null:
		GlowMark.light(target, glow)
	var burn: ToolTier = tool_effect_tier(&"burn")
	if burn != null:
		Burn.ignite(target, burn)
		var splash: ToolTier = tool_effect_tier(&"burn_splash")
		if splash != null and target is Node3D:
			Burn.splash(target as Node3D, splash.burn_splash_radius, burn)


## Reads reach and cooldown from the definition for this role: the
## companion reads the `companion_` fields.
func _read_attack_tuning() -> void:
	if hero == null:
		return
	if _is_companion_role():
		attack_range = hero.companion_attack_range
		attack_cooldown_seconds = hero.companion_attack_cooldown
	else:
		attack_range = hero.attack_range
		attack_cooldown_seconds = hero.attack_cooldown


## The role calls this every physics frame: it runs the attack cooldown
## and the tool's night light.
func _tick_attack(delta: float) -> void:
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	_update_tool_light()


## The night light is on at night while the hero is up, with a
## `night_light` tier, and not inside a torch's light (it doesn't stack).
func _update_tool_light() -> void:
	var lit: bool = has_tool_effect(&"night_light") and TimeManager.is_night() and not _down and not _near_torch()
	if lit and _tool_light == null:
		_tool_light = OmniLight3D.new()
		_tool_light.name = "ToolLight"
		_tool_light.light_color = Color(1.0, 0.62, 0.3)
		_tool_light.light_energy = 1.2
		_tool_light.position = Vector3(0, 1.1, 0)
		add_child(_tool_light)
	if _tool_light != null:
		_tool_light.visible = lit
		_tool_light.omni_range = get_tool_light_range()


func _near_torch() -> bool:
	if not is_inside_tree():
		return false
	for torch in get_tree().get_nodes_in_group(Torch.GROUP):
		if (torch as Torch).affects(global_position):
			return true
	return false


## Lands a melee hit on `target`, and on Big Swing's extra mobs, each
## with a `burst` puff.
func _land_swing(target: Node3D, burst: StringName) -> void:
	var extra: Array[Node3D] = HeroHits.extra_targets(self, target, &"melee")
	HeroHits.strike(self, target, get_attack_damage())
	Fx.burst(burst, target.global_position + Vector3(0, 0.7, 0))
	for other in extra:
		HeroHits.strike(self, other, get_attack_damage())
		Fx.burst(burst, other.global_position + Vector3(0, 0.7, 0))


## True in the companion role (it reads the definition's `companion_`
## attack fields). Asks Party, so it holds once the role group is joined:
## the companion joins before it reads its tuning; the player's hero reads
## its tuning in `_enter_tree`, where any answer but COMPANION is right.
func _is_companion_role() -> bool:
	return Party.role_of(self) == Party.COMPANION


## Role hook: how the attack starts (the swing or shot animation, at
## `_attack_anim_speed()`, whose contact frame times the hit).
func _show_attack(_target: Node3D) -> void:
	_visual.play_action(&"attack", _attack_anim_speed())


## Role hook: a melee swing at `target`, at the contact frame with the
## target in reach. By default it just lands.
func _swing(target: Node3D) -> void:
	_land_swing(target, &"hit")


# --- Progress ------------------------------------------------------------
# Stats from the definition, the level-up stat bumps, then `leveled`.
# The perk manager listens to `leveled` (not ProgressionManager's raw
# level-up), so the picker always opens after the new HP is applied,
# whatever order the autoloads connected in.

## The hero reached `level`, its stat bumps already applied. Also fires
## while a save is restored (`RunSession.is_restoring()`).
signal leveled(level: int)


## The role calls this once in `_ready`: sets max HP and attack damage
## from the stats, fills HP and registers with ProgressionManager.
func _setup_progress() -> void:
	if stats != null:
		max_hp = stats.base_max_health
		attack_damage = stats.base_attack_damage
	current_hp = max_hp
	ProgressionManager.register_character(self, stats)
	if not ProgressionManager.level_up.is_connected(_on_progression_level_up):
		ProgressionManager.level_up.connect(_on_progression_level_up)
	PerkManager.watch(self)


func _on_progression_level_up(character: Node, level: int) -> void:
	if character != self or stats == null:
		return
	attack_damage += stats.attack_damage_per_level
	max_hp += stats.max_health_per_level
	current_hp = mini(max_hp, current_hp + stats.max_health_per_level)
	health_changed.emit(current_hp, max_hp)
	leveled.emit(level)
	_show_level_up(level, RunSession.is_restoring())


## Role hook: the level-up's feedback, after `leveled` (so the perk
## picker is already open). `quiet` while a save is restored.
func _show_level_up(_level: int, _quiet: bool) -> void:
	pass


# --- Saving --------------------------------------------------------------
# A saving system. The hero's entry in the save file
# is "player" for the player's hero and "sibling" for the companion
# (their names before hero select). The hero writes its own part of it;
# ProgressionManager and PerkManager write its XP and perks there too.

## Saves from before hero select name the signature tool by the role's
## old hero: Leo's stick (the player) and Nela's slingshot (the sibling).
## Saves from before tool tiers hold `signature: true`. Both load as
## tier 1; today's saves hold the tier as `tier`.
const LEGACY_SIGNATURE_KEYS: Dictionary = {"player": "stick", "sibling": "slingshot"}


## The key of this hero's entry in the save file, by role.
func save_key() -> String:
	return "sibling" if _is_companion_role() else "player"


## {save_key(): the hero's own part of its entry}.
func save_state() -> Dictionary:
	return {save_key(): _save_entry()}


## Takes back the hero's own part of its saved entry (missing keys keep
## a fresh hero's values).
func load_state(data: Dictionary) -> void:
	var entry: Variant = data.get(save_key(), {})
	if entry is Dictionary:
		_load_entry(entry)


## A fresh run's hero, set quietly (no `down_changed`): the base stats
## (level-up bumps gone), no signature tool tier, up at full HP, and
## registered with ProgressionManager again at level 1 (it runs after
## ProgressionManager's reset). `health_changed` still updates the bars.
func reset() -> void:
	if tool_tier > 0 and hero != null:
		for n in range(1, tool_tier + 1):
			var factor: float = _range_factor_of(hero.tier(n))
			if factor > 0.0:
				attack_range /= factor
		tool_tier = 0
		_update_tool_light()
	_shot_count = 0
	_cancel_wind_up()
	if stats != null:
		max_hp = stats.base_max_health
		attack_damage = stats.base_attack_damage
	current_hp = max_hp
	_invulnerable_remaining = 0.0
	_regen_accumulator = 0.0
	if _down:
		_down = false
		_visual.unlock()
		_on_down_changed(false)
	ProgressionManager.register_character(self, stats)
	health_changed.emit(current_hp, max_hp)


## The role adds its own keys (the companion's task).
func _save_entry() -> Dictionary:
	return {"tier": tool_tier}


## The role reads its own keys after calling this.
func _load_entry(entry: Dictionary) -> void:
	var legacy: String = LEGACY_SIGNATURE_KEYS.get(save_key(), "")
	var tier: int = int(entry.get("tier", 1 if bool(entry.get("signature", entry.get(legacy, false))) else 0))
	set_tool_tier(tier, RunSession.is_restoring())


# --- Gathering and shared queries ----------------------------------------
# One gather path for both roles: start on a resource node, cancel, ask
# whether it is running, and hear when it finished. The node's own timer
# runs the gather; the role decides how it looks (`_on_gather_started`).

## The hero finished gathering `node` (the node paid out).
signal gather_finished(node: ResourceNode)

var _gather_node: ResourceNode = null


## Starts gathering `node` now (the hero should be next to it). Any other
## gather is cancelled first. False if the node won't have the hero: it
## is depleted, someone else is on it, or the stash is full.
func start_gather(node: ResourceNode) -> bool:
	if node == null or not is_instance_valid(node) or _down:
		return false
	if node == gather_target():
		return true
	cancel_gather()
	if not node.begin_gather(self):
		return false
	_gather_node = node
	if not node.gathered.is_connected(_on_gather_node_gathered):
		node.gathered.connect(_on_gather_node_gathered)
	_on_gather_started(node)
	return true


## Stops the current gather, if any; the node gives nothing for it.
func cancel_gather() -> void:
	var node: ResourceNode = _gather_node
	_gather_node = null
	if node == null or not is_instance_valid(node):
		return
	if node.gathered.is_connected(_on_gather_node_gathered):
		node.gathered.disconnect(_on_gather_node_gathered)
	node.cancel_gather(self)


## True while a gather runs on a node that still exists.
func is_gathering() -> bool:
	return _gather_node != null and is_instance_valid(_gather_node)


## The node being gathered, or null.
func gather_target() -> ResourceNode:
	return _gather_node if is_gathering() else null


func _on_gather_node_gathered(actor: Node, _id: StringName, _amount: int) -> void:
	if actor != self:
		return
	var node: ResourceNode = _gather_node
	if is_instance_valid(node) and node.gathered.is_connected(_on_gather_node_gathered):
		node.gathered.disconnect(_on_gather_node_gathered)
	_gather_node = null
	gather_finished.emit(node)


## Role hook: how starting a gather on `node` looks.
func _on_gather_started(_node: ResourceNode) -> void:
	pass


## The nearest mob within `within` metres (straight-line), or null.
func nearest_mob(within: float) -> Node3D:
	var best: Node3D = null
	var best_d_sq: float = within * within
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob: Node3D = node as Node3D
		if mob == null or not is_instance_valid(mob):
			continue
		var d_sq: float = mob.global_position.distance_squared_to(global_position)
		if d_sq < best_d_sq:
			best_d_sq = d_sq
			best = mob
	return best


## Distance to `point` on the ground plane (height ignored).
func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


## How far `node`'s collision reaches out from its centre, for "close
## enough to gather, repair or use". Settled drift (hero-core): a node
## without a cylinder, sphere or box shape counts as 0.4 m, the player's
## old value (the companion used 0.5).
static func _node_radius(node: Node3D) -> float:
	var shape: CollisionShape3D = node.get_node_or_null("Collision") as CollisionShape3D
	if shape != null and shape.shape is CylinderShape3D:
		return (shape.shape as CylinderShape3D).radius
	if shape != null and shape.shape is SphereShape3D:
		return (shape.shape as SphereShape3D).radius
	if shape != null and shape.shape is BoxShape3D:
		var box: Vector3 = (shape.shape as BoxShape3D).size
		return maxf(box.x, box.z) * 0.5
	return 0.4


# --- Look ----------------------------------------------------------------
# What the hero's head turns toward (HeadLook's order), picked every
# frame in both roles and handed to the visual. In `_process`, not the
# role's physics tick, so it follows a hero whose AI is held still.

var _glance: HeadLook.Glance = HeadLook.Glance.new()


func _process(delta: float) -> void:
	if _visual == null:
		return
	var glancing: bool = _glance.tick(delta)
	if _down:
		_visual.set_look_focus(null)
		return
	var fight: Node3D = _fight_target()
	var work: Node3D = _work_target()
	var idle: bool = fight == null and work == null and Vector2(velocity.x, velocity.z).length() < 0.2
	var mobs: Array = get_tree().get_nodes_in_group("mobs") if idle and TimeManager.is_night() else []
	_visual.set_look_focus(HeadLook.pick(global_position, fight, work, idle and TimeManager.is_night(), mobs,
		Party.other(self), glancing))


## The mob the hero is fighting, or null: its last attack's target while
## the cooldown runs. The player's hero also counts its attack command.
func _fight_target() -> Node3D:
	if _attack_cooldown_remaining > 0.0 and is_instance_valid(_attack_target):
		return _attack_target
	return null


## What the hero is working on, or null: the node it gathers. The roles
## add the building they build or repair.
func _work_target() -> Node3D:
	return gather_target()
