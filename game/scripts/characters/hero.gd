class_name Hero
extends CharacterBody3D

## Hero
##
## Everything Leo or Nela does whichever role they play (hero-core spec).
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
## Health, Attack, Progress, and Gathering with the shared queries.

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
		_visual.play_action(&"hit", 1.4)


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
# Attacking a target, reach, readiness, damage and the signature tool.
# The module owns the cooldown and the melee vs pebble branch; HeroHits
# stays the perk math underneath (every hit goes through its strike()).
# The role adds the feel: `_show_attack` (the swing animation) and
# `_swing` (the player's wind-up and hit-stop, the companion's sparkle).
# Settled: the signature's float text lasts 2.8 s in both roles (the
# companion's was 2.7 s).

## A swing or a pebble left the hero, aimed at `target`.
signal attacked(target: Node3D)

## Damage per hit before perks. Set from the stats' base attack; level-
## ups and the signature tool add to it.
@export var attack_damage: int = 4
## Reach before perks, from the definition by role (`_read_attack_tuning`).
## Read `get_attack_range()` wherever the reach matters.
@export var attack_range: float = 2.0
## Seconds between attacks, from the definition by role.
@export var attack_cooldown_seconds: float = 0.65

## Tool tiers: the tier of the hero's tool (0: none yet). Unused until
## the tool tiers feature.
var tool_tier: int = 0
## The hero's signature tool (Leo's Sturdy Stick, Nela's Slingshot) from
## the Crafting Table, once per run. Save and crafting read it by name.
var has_signature: bool = false

var _attack_cooldown_remaining: float = 0.0
## What the last attack was aimed at (for `is_attacking`).
var _attack_target: Node3D = null


## Attacks `target` now: starts the cooldown, then fires a pebble (a
## ranged hero) or swings (melee). It does not wait for the cooldown:
## callers check `is_attack_ready()` first. False if the hero is down or
## `target` cannot be hit.
func attack(target: Node3D) -> bool:
	if _down or target == null or not is_instance_valid(target) or not target.has_method("take_damage"):
		return false
	_attack_cooldown_remaining = attack_cooldown_seconds
	_attack_target = target
	_show_attack(target)
	attacked.emit(target)
	if hero != null and hero.ranged:
		PebbleShot.fire(self, target, get_attack_damage())
	else:
		_swing(target)
	return true


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


## Applies the signature tool, once per run: the definition's damage
## bonus, and its range factor for this role (the companion reads
## `companion_signature_range_factor`).
func apply_signature() -> void:
	if has_signature or hero == null:
		return
	has_signature = true
	attack_damage += hero.signature_damage_bonus
	attack_range *= hero.companion_signature_range_factor if _is_companion_role() else hero.signature_range_factor
	Fx.float_text(self, "%s!" % hero.signature_label.to_upper(), Color(1.0, 0.85, 0.4), 2.8)
	Fx.burst(&"level_up", global_position)


## Tool tiers: HeroHits.strike calls this for every hit the hero lands
## (a swing, a Big Swing extra, a pebble, a Ricochet bounce), after the
## damage. Empty until the tool tiers feature (burn, double shot, pierce).
func on_attack_hit(_target: Node, _damage: int) -> void:
	pass


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


## The role calls this every physics frame: it runs the attack cooldown.
func _tick_attack(delta: float) -> void:
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)


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


## Role hook: how the attack starts (the swing or shot animation).
func _show_attack(_target: Node3D) -> void:
	_visual.play_action(&"attack", 1.5)


## Role hook: a melee swing at `target`. By default it lands at once.
func _swing(target: Node3D) -> void:
	_land_swing(target, &"hit")


# --- Progress ------------------------------------------------------------
# Stats from the definition, the level-up stat bumps, then `leveled`.
# The perk manager listens to `leveled` (not ProgressionManager's raw
# level-up), so the picker always opens after the new HP is applied,
# whatever order the autoloads connected in.

## The hero reached `level`, its stat bumps already applied. Also fires
## while a save is restored (`ProgressionManager.is_restoring`).
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
	_show_level_up(level, ProgressionManager.is_restoring)


## Role hook: the level-up's feedback, after `leveled` (so the perk
## picker is already open). `quiet` while a save is restored.
func _show_level_up(_level: int, _quiet: bool) -> void:
	pass


# --- Saving --------------------------------------------------------------
# A saving system (run lifecycle 03). The hero's entry in the save file
# is "player" for the player's hero and "sibling" for the companion
# (their names before feature 034). The hero writes its own part of it;
# ProgressionManager and PerkManager write its XP and perks there too.

## Saves from before feature 034 name the signature tool by the role's
## old hero: Leo's stick (the player) and Nela's slingshot (the sibling).
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


## A fresh run's hero: no signature tool yet, full HP.
func reset() -> void:
	if has_signature and hero != null:
		has_signature = false
		attack_damage -= hero.signature_damage_bonus
		var factor: float = hero.companion_signature_range_factor if _is_companion_role() else hero.signature_range_factor
		if factor > 0.0:
			attack_range /= factor
	if _down:
		revive(max_hp)
	else:
		current_hp = max_hp
		health_changed.emit(current_hp, max_hp)


## The role adds its own keys (the companion's task).
func _save_entry() -> Dictionary:
	return {"signature": has_signature}


## The role reads its own keys after calling this.
func _load_entry(entry: Dictionary) -> void:
	var legacy: String = LEGACY_SIGNATURE_KEYS.get(save_key(), "")
	if bool(entry.get("signature", entry.get(legacy, false))):
		apply_signature()


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
