class_name Party
extends RefCounted

## Party
##
## Who is who in the running camp (hero-core spec): the player's hero,
## the companion, each one's other hero, and a hero's role. Use it
## instead of looking heroes up by group name. It reads the live scene,
## so after a hero swap (a new run) it names the new heroes.
##
##   Party.player_hero()        # the hero the player plays
##   Party.companion()          # the hero tagging along
##   Party.other(hero)          # the sibling of `hero`
##   Party.role_of(hero)        # PLAYER, COMPANION or &""

const PLAYER: StringName = &"player"
const COMPANION: StringName = &"companion"

## The scene groups each role's hero joins (kept for the many callers
## that still look them up directly).
const _GROUPS: Dictionary = {PLAYER: &"player", COMPANION: &"companions"}


## The hero the player plays. Null outside a run.
static func player_hero() -> Hero:
	return _first(PLAYER)


## The companion hero. Null outside a run.
static func companion() -> Hero:
	return _first(COMPANION)


## Both heroes in the camp, the player's hero first.
static func heroes() -> Array[Hero]:
	var out: Array[Hero] = []
	for role in [PLAYER, COMPANION]:
		var hero: Hero = _first(role)
		if hero != null:
			out.append(hero)
	return out


## The other sibling: the companion for the player's hero, the player's
## hero for the companion. Null if `hero` is neither, or the other is gone.
static func other(hero: Node) -> Hero:
	match role_of(hero):
		PLAYER:
			return companion()
		COMPANION:
			return player_hero()
	return null


## PLAYER or COMPANION for a hero; &"" for anything else. The role is
## its role group, so a stand-in node in that group counts too (the
## validator's perk probes).
static func role_of(hero: Node) -> StringName:
	if not is_instance_valid(hero):
		return &""
	for role in _GROUPS:
		if hero.is_in_group(_GROUPS[role]):
			return role
	return &""


static func _first(role: StringName) -> Hero:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	for node in tree.get_nodes_in_group(_GROUPS[role]):
		if node is Hero and not node.is_queued_for_deletion():
			return node as Hero
	return null
