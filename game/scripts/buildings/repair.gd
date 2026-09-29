class_name Repair
extends RefCounted

## Repair
##
## Shared rules for fixing damaged structures (feature 017). Anything
## in the "repairable" group (placed buildings and the campfire) exposes
## get_missing_hp(), repair(amount) and repair_per_tap. One "tap" of
## the hammer costs a piece of wood, restores repair_per_tap HP and
## gives the repairer a little XP. Leo taps while he stands next to a
## damaged building; Nela does it on her own with the Repair task.

const WOOD_ID: StringName = &"wood"
const WOOD_PER_TAP: int = 1
const TAP_SECONDS: float = 0.7
const XP_PER_TAP: int = 1
const GROUP: StringName = &"repairable"


static func needs_repair(target: Node) -> bool:
	return target != null and is_instance_valid(target) and target.is_inside_tree() \
		and target.is_in_group(GROUP) and int(target.get_missing_hp()) > 0


## Spends wood and fixes a chunk of `target`. False when there is
## nothing to fix or no wood (the caller shows the "need wood" hint).
static func tap(target: Node, actor: Node) -> bool:
	if not needs_repair(target):
		return false
	if not ResourceManager.spend(WOOD_ID, WOOD_PER_TAP):
		return false
	target.repair(int(target.get("repair_per_tap")))
	if actor != null:
		ProgressionManager.award_xp(actor, XP_PER_TAP, &"repair")
	var anchor: Node3D = target as Node3D
	if anchor != null:
		Fx.burst(&"repair", anchor.global_position + Vector3(0, 0.8, 0))
		Fx.float_text(anchor, "+%d" % int(target.get("repair_per_tap")), Color(0.55, 1.0, 0.6), 1.8)
	GameManager.record(&"repairs")
	return true


## The structure that most needs fixing: the lowest HP fraction, with the
## campfire first once it is below 70% (losing it ends the run).
static func most_damaged(tree: SceneTree) -> Node3D:
	var best: Node3D = null
	var best_score: float = 0.0
	for node in tree.get_nodes_in_group(GROUP):
		if not needs_repair(node):
			continue
		var max_hp: float = float(node.get_max_hp())
		var missing: float = float(node.get_missing_hp()) / maxf(max_hp, 1.0)
		var score: float = missing + (1.0 if node.is_in_group("base_core") and missing > 0.3 else 0.0)
		if score > best_score:
			best_score = score
			best = node as Node3D
	return best
