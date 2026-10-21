class_name TorchSaves
extends RefCounted

## TorchSaves
##
## The saving system for planted torches (run lifecycle 03): lists the
## ones still burning for the save file ("torches") and plants them again
## on Continue. At the dawn autosave only Ember Heart torches are left
## (plain ones burn out at that dawn). Each torch writes and reads its
## own line (Torch.save_entry / Torch.rebuild). A Glow Lantern's aura
## (the same script, inside its building) is rebuilt with its building.

const KEY: String = "torches"

var _tree: SceneTree = null


func _init(tree: SceneTree) -> void:
	_tree = tree


## {"torches": [entry, ...]}: every planted torch still burning.
func save_state() -> Dictionary:
	var out: Array = []
	for torch in _planted():
		out.append(torch.save_entry())
	return {KEY: out}


## Plants the saved torches again in the current scene. Older saves have
## none.
func load_state(data: Dictionary) -> void:
	var entries: Variant = data.get(KEY, [])
	if not entries is Array or _tree.current_scene == null:
		return
	for entry in entries:
		if entry is Dictionary:
			Torch.rebuild(entry, _tree.current_scene)


## A fresh run has no planted torches: puts every one out at once.
func reset() -> void:
	for torch in _planted():
		torch.remove_from_group(Torch.GROUP)
		torch.queue_free()


func _planted() -> Array[Torch]:
	var out: Array[Torch] = []
	for node in _tree.get_nodes_in_group(Torch.GROUP):
		var torch: Torch = node as Torch
		if torch != null and torch.get_parent() == _tree.current_scene and torch.burns_out_at_dawn:
			out.append(torch)
	return out
