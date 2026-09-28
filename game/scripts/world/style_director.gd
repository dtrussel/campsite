extends Node

## StyleDirector
##
## Gives every mesh in the scene the house look (see Stylize) without
## each scene having to remember to. Styles what is already in the
## tree on ready, then anything added later (placed buildings, spawned
## mobs, torches). Characters restyle themselves afterwards with their
## own profile, so this only sets the default "prop" profile.


func _ready() -> void:
	Stylize.apply(get_parent(), "prop")
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var mesh: MeshInstance3D = node as MeshInstance3D
	if mesh == null or mesh.has_meta(&"stylized"):
		return
	# Wait a frame so the mesh and its materials are fully set up.
	_style_later.call_deferred(mesh)


func _style_later(mesh: MeshInstance3D) -> void:
	if is_instance_valid(mesh) and not mesh.has_meta(&"stylized"):
		Stylize.apply_mesh(mesh, "prop")
