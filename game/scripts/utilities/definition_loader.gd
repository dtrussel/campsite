class_name DefinitionLoader
extends RefCounted

## DefinitionLoader
##
## Loads every .tres under a directory. Safe for exported builds: in
## an exported PCK, text resources are listed as "foo.tres.remap" (or
## converted to "foo.res"), so a naive ends_with(".tres") scan finds
## nothing. We strip the export suffixes and hand the original path to
## load(), which follows the remap.


static func load_all(dir_path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_warning("DefinitionLoader: cannot open %s" % dir_path)
		return out
	var seen: Dictionary = {}
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var clean: String = file_name.trim_suffix(".remap").trim_suffix(".import")
			if clean.ends_with(".tres") or clean.ends_with(".res"):
				if not seen.has(clean):
					seen[clean] = true
					var loaded: Resource = load(dir_path.path_join(clean))
					if loaded != null:
						out.append(loaded)
					else:
						push_warning("DefinitionLoader: failed to load %s" % clean)
		file_name = dir.get_next()
	dir.list_dir_end()
	return out
