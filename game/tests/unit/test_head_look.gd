extends "res://tests/unit/unit_test.gd"

## The head look-at's target order: the attack target while fighting,
## the work target while gathering or building, the nearest mob within
## about 6 m while idle at night, otherwise the other hero now and then.

var _made: Array[Node3D] = []
var _mob_near: Node3D
var _mob_nearer: Node3D
var _mob_far: Node3D
var _foe: Node3D
var _tree_node: Node3D
var _sibling: Node3D


func _init() -> void:
	_mob_near = _at(Vector3(4.0, 0, 0))
	_mob_nearer = _at(Vector3(0, 0, -3.0))
	_mob_far = _at(Vector3(7.0, 0, 0))
	_foe = _at(Vector3(1.5, 0, 0))
	_tree_node = _at(Vector3(0, 0, 1.2))
	_sibling = _at(Vector3(-2.0, 0, 2.0))


func after_each() -> void:
	for node in _made:
		if is_instance_valid(node):
			node.free()


## A node standing at `point` (outside the tree: the rule reads its position).
func _at(point: Vector3) -> Node3D:
	var node: Node3D = Node3D.new()
	node.position = point
	_made.append(node)
	return node


func _pick(fight: Variant, work: Variant, idle_at_night: bool, mobs: Array, glancing: bool) -> Node3D:
	return HeadLook.pick(Vector3.ZERO, fight, work, idle_at_night, mobs, _sibling, glancing)


func test_fighting_looks_at_the_attack_target() -> void:
	check(_pick(_foe, _tree_node, true, [_mob_nearer], true) == _foe,
		"while fighting the hero looks at the attack target, over work, mobs and the sibling")


func test_working_looks_at_the_work_target() -> void:
	check(_pick(null, _tree_node, true, [_mob_nearer], true) == _tree_node,
		"while gathering or building the hero looks at the work target, over mobs and the sibling")


func test_idle_at_night_looks_at_the_nearest_mob_in_range() -> void:
	check(_pick(null, null, true, [_mob_near, _mob_far, _mob_nearer], true) == _mob_nearer,
		"idle at night the hero looks at the nearest mob (3 m), not one at 4 m or 7 m")
	check(_pick(null, null, true, [_mob_far], false) == null,
		"a mob 7 m off is out of range, and with no glance due there is nothing to look at")


func test_mobs_are_ignored_unless_idle_at_night() -> void:
	check(_pick(null, null, false, [_mob_nearer], false) == null,
		"by day, or not idle, a nearby mob draws no look")


func test_otherwise_the_other_hero_now_and_then() -> void:
	check(_pick(null, null, false, [], true) == _sibling, "with a glance due the hero looks at the other hero")
	check(_pick(null, null, true, [_mob_far], true) == _sibling,
		"idle at night with no mob in range, a due glance goes to the other hero")
	check(_pick(null, null, false, [], false) == null, "with no glance due the hero looks at nothing")


func test_gone_targets_are_skipped() -> void:
	var gone: Node3D = _at(Vector3(1, 0, 0))
	gone.free()
	check(_pick(gone, null, true, [gone, _mob_near], false) == _mob_near,
		"a freed attack target or mob is skipped for the next rule that applies")
	check(HeadLook.pick(Vector3.ZERO, null, null, false, [], null, true) == null,
		"a glance with no other hero looks at nothing")
