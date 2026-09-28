extends Node3D

## RandomVariant
##
## Keeps one of this node's model children visible, chosen from the
## node's world position, so repeated scene instances (trees, pines)
## show different variants deterministically.


func _ready() -> void:
	var models: Array[Node3D] = []
	for child in get_children():
		if child is Node3D:
			models.append(child)
	if models.size() < 2:
		return
	var p: Vector3 = global_position
	var pick: int = absi(int(floor(p.x * 7.0 + p.z * 13.0))) % models.size()
	for i in range(models.size()):
		models[i].visible = i == pick
		if i != pick:
			models[i].queue_free()
