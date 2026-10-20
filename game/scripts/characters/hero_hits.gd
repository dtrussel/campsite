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

## How close to the campfire (the "base_core" node) counts as "near the
## fire" for Stand Firm, in metres.
const NEAR_FIRE_RADIUS: float = 6.0


## The factor on `attacker`'s damage against `target`. 1.0 without perks.
## Add per-target multipliers here (Twin Strike: +50% on a mob the other
## hero is hitting, via the mob's _last_damage_source).
static func damage_factor(_attacker: Node, _target: Node) -> float:
	return 1.0


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
	return amount


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
	var factor: float = 1.0
	for id in PerkManager.perks_of(character):
		var perk: PerkDefinition = PerkManager.get_definition(id)
		if perk.effect_kind == &"flag" and perk.flag_name() == &"stand_firm" and is_near_fire(character):
			factor *= perk.value
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
