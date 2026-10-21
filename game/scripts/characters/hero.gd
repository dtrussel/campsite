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
var _invulnerable_remaining: float = 0.0
var _regen_accumulator: float = 0.0


## True from reaching 0 HP until `revive`.
func is_down() -> bool:
	return _down


## True while the window after a hit ignores further hits.
func is_invulnerable() -> bool:
	return _invulnerable_remaining > 0.0


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
# hero-core 02: attack, reach, readiness, damage, the signature tool.


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
		_add_attack_damage(stats.base_attack_damage, true)
	current_hp = max_hp
	ProgressionManager.register_character(self, stats)
	if not ProgressionManager.level_up.is_connected(_on_progression_level_up):
		ProgressionManager.level_up.connect(_on_progression_level_up)
	PerkManager.watch(self)


func _on_progression_level_up(character: Node, level: int) -> void:
	if character != self or stats == null:
		return
	_add_attack_damage(stats.attack_damage_per_level, false)
	max_hp += stats.max_health_per_level
	current_hp = mini(max_hp, current_hp + stats.max_health_per_level)
	health_changed.emit(current_hp, max_hp)
	leveled.emit(level)
	_show_level_up(level, ProgressionManager.is_restoring)


## Role hook: sets (`base`) or raises the attack damage the role holds.
func _add_attack_damage(_amount: int, _base: bool) -> void:
	pass


## Role hook: the level-up's feedback, after `leveled` (so the perk
## picker is already open). `quiet` while a save is restored.
func _show_level_up(_level: int, _quiet: bool) -> void:
	pass


# --- Gathering and shared queries ----------------------------------------
# hero-core 04: gathering, nearest mob, node radius and flat distance.
