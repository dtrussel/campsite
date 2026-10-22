class_name GlowMark
extends OmniLight3D

## GlowMark
##
## The Glow Sling's glow: a mob its pebble hits lights up for the glow
## tier's `glow_seconds` (ToolTier), a small pale-green light on the mob. Lives as a child of
## the mob and frees itself when done. A new hit on a glowing mob starts
## the glow over (it never stacks).
##
##   GlowMark.light(mob, tier) # from Hero.on_attack_hit
##   GlowMark.on(mob)          # the mob's glow, or null

const NODE_NAME: String = "GlowMark"

var _elapsed: float = 0.0
var _seconds: float = 1.0
var _energy: float = 1.0


## Lights `target` up (or starts its glow over) as the glow `tier`
## says. Ignored for anything that isn't in the tree.
static func light(target: Node, tier: ToolTier) -> GlowMark:
	if tier == null or target == null or not is_instance_valid(target) or not target.is_inside_tree() or not target is Node3D:
		return null
	var mark: GlowMark = on(target)
	if mark == null:
		mark = GlowMark.new()
		mark.name = NODE_NAME
		mark.light_color = Color(0.7, 1.0, 0.75)
		mark.shadow_enabled = false
		mark.position = Vector3(0, 0.8, 0)
		target.add_child(mark)
	mark._seconds = maxf(tier.glow_seconds, 0.01)
	mark._energy = tier.glow_energy
	mark.light_energy = tier.glow_energy
	mark.omni_range = tier.glow_range
	mark._elapsed = 0.0
	return mark


## The glow on `target`, or null.
static func on(target: Node) -> GlowMark:
	if target == null or not is_instance_valid(target):
		return null
	var mark: GlowMark = target.get_node_or_null(NODE_NAME) as GlowMark
	return null if mark == null or mark.is_queued_for_deletion() else mark


func _physics_process(delta: float) -> void:
	_elapsed += delta
	light_energy = _energy * clampf(1.0 - _elapsed / _seconds, 0.0, 1.0) + 0.2
	if _elapsed >= _seconds:
		queue_free()
