class_name BuildingSaves
extends RefCounted

## BuildingSaves
##
## The saving system for the camp's buildings and blueprints:
## lists them for the save file ("buildings") and rebuilds
## them on Continue. Each building writes and reads its own line
## (Building.save_entry / Building.rebuild). Destroyed ones are left out.

const KEY: String = "buildings"

var _tree: SceneTree = null


func _init(tree: SceneTree) -> void:
	_tree = tree


## {"buildings": [entry, ...]}: every standing building and blueprint.
func save_state() -> Dictionary:
	var out: Array = []
	for building in _standing():
		out.append(building.save_entry())
	return {KEY: out}


## Rebuilds the saved buildings in the current scene. A save without
## buildings rebuilds none.
func load_state(data: Dictionary) -> void:
	var entries: Variant = data.get(KEY, [])
	if not entries is Array or _tree.current_scene == null:
		return
	for entry in entries:
		if entry is Dictionary:
			Building.rebuild(entry, _tree.current_scene)


## A fresh run has no buildings: removes every placed one.
func reset() -> void:
	for node in _tree.get_nodes_in_group(Building.BUILDINGS_GROUP):
		if not node.is_queued_for_deletion():
			node.remove_from_group(Building.BLUEPRINT_GROUP)
			node.remove_from_group(Building.BUILDINGS_GROUP)
			node.queue_free()


func _standing() -> Array[Building]:
	var out: Array[Building] = []
	for node in _tree.get_nodes_in_group(Building.BUILDINGS_GROUP):
		var building: Building = node as Building
		if building != null and building.definition != null and building.current_hp > 0:
			out.append(building)
	return out
