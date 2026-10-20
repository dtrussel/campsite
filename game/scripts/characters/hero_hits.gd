class_name HeroHits
extends RefCounted

## HeroHits
##
## Where a hero's hits and hurts meet the perk cards (perk cards,
## .scratch/perk-cards, ticket 04). Both heroes go through here, whether
## the player plays them (PlayerController) or they tag along
## (Companion), so a perk works the same either way:
##
##   HeroHits.strike(attacker, mob, damage)               # every hit lands here
##   HeroHits.extra_targets(attacker, mob, &"melee")      # Big Swing, Ricochet
##   HeroHits.damage_taken(hero, amount)                  # Stand Firm
##
## Every melee swing, pebble and pebble bounce deals its damage through
## strike(), and so through damage_factor(): the one place a per-target
## damage multiplier goes (Twin Strike, ticket 05).
##
## The sibling cards (ticket 05) need "the other hero": the companion for
## the player, the player for the companion (other_hero()). "A mob the
## other hero is hitting" means one the other hero struck within
## TWIN_STRIKE_SECONDS of game time. strike() stamps each hero hit on the
## mob (the HIT_META meta: hero instance id -> game seconds); the mob's
## own _last_damage_source is not enough, as your own hits overwrite it.

## How close to the campfire (the "base_core" node) counts as "near the
## fire" for Stand Firm, in metres.
const NEAR_FIRE_RADIUS: float = 6.0
## How recently (game seconds) the other hero must have hit a mob for
## Twin Strike to count it as "a mob the other hero is hitting".
const TWIN_STRIKE_SECONDS: float = 2.0
## The meta on a struck mob: {hero instance id: game seconds of the hit}.
const HIT_META: StringName = &"hero_hit_at"
const TWIN_STRIKE: StringName = &"twin_strike"
const CHEER_UP: StringName = &"cheer_up"
const STAND_FIRM: StringName = &"stand_firm"


## The factor on `attacker`'s damage against `target`. 1.0 without perks.
## Twin Strike: x`value` (1.5) per copy on a mob the other hero is
## hitting. Further per-target multipliers go here, each its own factor.
static func damage_factor(attacker: Node, target: Node) -> float:
	var factor: float = 1.0
	if attacker == null or target == null:
		return factor
	factor *= _flag_factor(attacker, TWIN_STRIKE,
		func() -> bool: return is_hitting(other_hero(attacker), target))
	return factor


## `flag`'s card value once per copy held (stacking cards multiply),
## when `applies` says it counts now. 1.0 without the card.
static func _flag_factor(character: Node, flag: StringName, applies: Callable) -> float:
	var copies: int = PerkManager.flag_count(character, flag)
	var perk: PerkDefinition = PerkManager.get_definition(flag)
	if copies == 0 or perk == null or not applies.call():
		return 1.0
	return pow(perk.value, copies)


## `base` damage after damage_factor(), never below 1 for a real hit.
static func damage_against(attacker: Node, target: Node, base: int) -> int:
	if base <= 0:
		return base
	return maxi(1, roundi(base * damage_factor(attacker, target)))


## Deals one hit of `base` damage from `attacker` to `target`. Returns the
## damage dealt, or 0 if `target` cannot be hit.
static func strike(attacker: Node, target: Node, base: int) -> int:
	if target == null or not is_instance_valid(target) or not target.has_method("take_damage"):
		return 0
	var amount: int = damage_against(attacker, target, base)
	target.take_damage(amount, attacker)
	_stamp_hit(attacker, target)
	return amount


## The game clock the hit stamps use (PerkManager.clock): it follows
## Engine.time_scale (hit stop, the perk picker's slow-down, test speed)
## and stops while paused.
static func game_seconds() -> float:
	return PerkManager.clock


## The other sibling: the companion for the player, the player for the
## companion. Null if `character` is neither, or the other is gone.
static func other_hero(character: Node) -> Node3D:
	if character == null or not character.is_inside_tree():
		return null
	var group: StringName
	if character.is_in_group("player"):
		group = &"companions"
	elif character.is_in_group("companions"):
		group = &"player"
	else:
		return null
	for node in character.get_tree().get_nodes_in_group(group):
		if node != character and node.get("hero") is HeroDefinition:
			return node as Node3D
	return null


## True if `hero` struck `target` within TWIN_STRIKE_SECONDS.
static func is_hitting(hero: Node, target: Node) -> bool:
	if hero == null or target == null or not target.has_meta(HIT_META):
		return false
	var stamps: Dictionary = target.get_meta(HIT_META)
	if not stamps.has(hero.get_instance_id()):
		return false
	return game_seconds() - float(stamps[hero.get_instance_id()]) <= TWIN_STRIKE_SECONDS


static func _stamp_hit(attacker: Node, target: Node) -> void:
	if attacker == null or not is_instance_valid(target) or not attacker.get("hero") is HeroDefinition:
		return
	var stamps: Dictionary = target.get_meta(HIT_META, {})
	stamps[attacker.get_instance_id()] = game_seconds()
	target.set_meta(HIT_META, stamps)


## The HP Cheer Up gives `other` when its holder levels up: `value` (a
## quarter) of `other`'s max HP. 0 without the card's data.
static func cheer_up_heal(other: Node) -> int:
	var perk: PerkDefinition = PerkManager.get_definition(CHEER_UP)
	if other == null or perk == null:
		return 0
	return maxi(1, roundi(int(other.get("max_hp")) * perk.value))


## Cheer Up: `character` levelled up, so the other hero heals too (once
## per copy). Knocked-out heroes stay down.
static func cheer_up(character: Node) -> void:
	var copies: int = PerkManager.flag_count(character, CHEER_UP)
	var other: Node3D = other_hero(character)
	if copies == 0 or other == null or bool(other.get("is_knocked_out")) or not other.has_method("heal"):
		return
	var before: int = int(other.get("current_hp"))
	other.call("heal", cheer_up_heal(other) * copies)
	var gained: int = int(other.get("current_hp")) - before
	if gained > 0:
		Fx.float_text(other, "+%d HP" % gained, Color(0.5, 1, 0.5))
		Fx.burst(&"heal", other.global_position)


## The other mobs a hit from `source` (&"melee" or &"pebble") on `first`
## also reaches, nearest first: one per `extra_targets` on the attacker's
## on_hit perks, within the longest `reach` of `first`. Empty without such
## perks.
static func extra_targets(attacker: Node, first: Node3D, source: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if attacker == null or first == null or not is_instance_valid(first) or not first.is_inside_tree():
		return out
	var count: int = 0
	var reach: float = 0.0
	for perk in PerkManager.on_hit_perks(attacker, source):
		count += perk.extra_targets
		reach = maxf(reach, perk.reach)
	if count <= 0 or reach <= 0.0:
		return out
	var candidates: Array[Node3D] = []
	for node in first.get_tree().get_nodes_in_group("mobs"):
		var mob: Node3D = node as Node3D
		if mob == null or mob == first or not is_instance_valid(mob) or int(mob.get("current_hp")) <= 0:
			continue
		if _flat(mob.global_position - first.global_position).length() <= reach:
			candidates.append(mob)
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(first.global_position) < b.global_position.distance_squared_to(first.global_position))
	out.assign(candidates.slice(0, count))
	return out


## The damage `character` takes from a hit of `amount`, after its perks:
## Stand Firm takes `value` of it (0.75) near the campfire.
static func damage_taken(character: Node3D, amount: int) -> int:
	if amount <= 0 or character == null:
		return amount
	var factor: float = _flag_factor(character, STAND_FIRM, func() -> bool: return is_near_fire(character))
	if is_equal_approx(factor, 1.0):
		return amount
	return maxi(1, roundi(amount * factor))


## True within NEAR_FIRE_RADIUS of the campfire.
static func is_near_fire(character: Node3D) -> bool:
	if character == null or not character.is_inside_tree():
		return false
	var base: Node3D = character.get_tree().get_first_node_in_group("base_core") as Node3D
	return base != null and _flat(character.global_position - base.global_position).length() <= NEAR_FIRE_RADIUS


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
