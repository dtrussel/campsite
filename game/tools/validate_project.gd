extends Node

## validate_project.gd
##
## Headless project validator (see docs/testing/test-strategy.md,
## "Data validation"). Runs as a scene so autoloads exist. From the
## repo root:
##
##   godot --headless --path game res://tools/validate_project.tscn
##
## 1. Loads every .gd, .tscn and .tres under res:// and fails on any
##    that does not load (parse errors, broken references, cycles).
## 2. Checks data integrity: ids are set and unique, scene paths
##    resolve, and every cost / recipe input refers to a real item.
## Exits 0 when clean, 1 otherwise.

const SKIP_DIRS: Array[String] = ["res://.godot", "res://addons"]

var _errors: PackedStringArray = PackedStringArray()


## Feature 029: the boot splash exists and the loading screen builds.
func _validate_key_art() -> void:
	var splash: String = String(ProjectSettings.get_setting("application/boot_splash/image", ""))
	if splash == "" or not FileAccess.file_exists(splash):
		_fail("boot splash image missing: '%s'" % splash)
	for i in LoadingScreen.SCREENS.size():
		var entry: Array = LoadingScreen.SCREENS[i]
		if not ResourceLoader.exists(String(entry[0])):
			_fail("loading screen art missing: %s" % entry[0])
		for tip in entry[1]:
			if String(tip[1]) != "" and not ResourceLoader.exists(String(tip[1])):
				_fail("loading tip icon missing: %s" % tip[1])
		var screen: LoadingScreen = LoadingScreen.preview(0.6, i)
		if screen.get_child_count() == 0:
			_fail("LoadingScreen.preview(%d) built nothing" % i)
		screen.free()


func _ready() -> void:
	var files: PackedStringArray = PackedStringArray()
	_collect("res://", files)
	for path in files:
		var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if loaded == null:
			_fail("failed to load %s" % path)
		elif loaded is GDScript and not (loaded as GDScript).can_instantiate():
			_fail("script does not compile: %s" % path)
	_validate_data()
	_validate_key_art()
	if _errors.is_empty():
		print("validate_project: OK (%d files checked)" % files.size())
		get_tree().quit(0)
	else:
		for message in _errors:
			printerr("validate_project: " + message)
		printerr("validate_project: FAILED with %d error(s)" % _errors.size())
		get_tree().quit(1)


func _validate_data() -> void:
	var item_ids: Dictionary = {}
	for res in DefinitionLoader.load_all("res://resources/items/"):
		var item: ResourceDefinition = res as ResourceDefinition
		if item == null:
			_fail("%s is not a ResourceDefinition" % res.resource_path)
			continue
		_check_id(item.id, item.resource_path, item_ids)

	var building_ids: Dictionary = {}
	for res in DefinitionLoader.load_all("res://resources/buildings/"):
		var building: BuildingDefinition = res as BuildingDefinition
		if building == null:
			_fail("%s is not a BuildingDefinition" % res.resource_path)
			continue
		_check_id(building.id, building.resource_path, building_ids)
		_check_scene(building.scene_path, building.resource_path)
		_check_items(building.cost, item_ids, building.resource_path)

	var mob_ids: Dictionary = {}
	for res in DefinitionLoader.load_all("res://resources/mobs/"):
		var mob: MobDefinition = res as MobDefinition
		if mob == null:
			_fail("%s is not a MobDefinition" % res.resource_path)
			continue
		_check_id(mob.id, mob.resource_path, mob_ids)
		_check_scene(mob.scene_path, mob.resource_path)
		if mob.drop_item != &"" and not item_ids.has(mob.drop_item):
			_fail("%s drops unknown item '%s'" % [mob.resource_path, mob.drop_item])

	var recipe_ids: Dictionary = {}
	for res in DefinitionLoader.load_all("res://resources/recipes/"):
		var recipe: CraftingRecipe = res as CraftingRecipe
		if recipe == null:
			_fail("%s is not a CraftingRecipe" % res.resource_path)
			continue
		_check_id(recipe.id, recipe.resource_path, recipe_ids)
		_check_items(recipe.inputs, item_ids, recipe.resource_path)
		if recipe.effect != &"" and not CraftingRecipe.EFFECTS.has(recipe.effect):
			_fail("%s has unknown effect '%s'" % [recipe.resource_path, recipe.effect])
		if recipe.effect == &"" or recipe.output_id != &"":
			if not item_ids.has(recipe.output_id):
				_fail("%s outputs unknown item '%s'" % [recipe.resource_path, recipe.output_id])
		if recipe.result_icon() == null:
			_fail("%s has no result icon (output item icon or icon_name)" % recipe.resource_path)

	_validate_audio()

	# Every item a building or recipe needs must be obtainable somewhere:
	# as a resource node yield/bonus or as a recipe output.
	var obtainable: Dictionary = {}
	for res in DefinitionLoader.load_all("res://resources/recipes/"):
		if (res as CraftingRecipe).output_id != &"":
			obtainable[(res as CraftingRecipe).output_id] = true
	for res in DefinitionLoader.load_all("res://resources/mobs/"):
		var drop: StringName = (res as MobDefinition).drop_item
		if drop != &"" and (res as MobDefinition).drop_every_n_kills > 0:
			obtainable[drop] = true
	var node_scenes: PackedStringArray = PackedStringArray()
	_collect("res://scenes/resources/", node_scenes)
	for scene_path in node_scenes:
		if not scene_path.ends_with(".tscn"):
			continue
		var node: ResourceNode = (load(scene_path) as PackedScene).instantiate() as ResourceNode
		if node == null:
			continue
		if node.definition != null:
			obtainable[node.definition.id] = true
		if node.bonus_definition != null:
			obtainable[node.bonus_definition.id] = true
		node.free()
	var needed: Dictionary = {}
	for res in DefinitionLoader.load_all("res://resources/buildings/"):
		needed.merge((res as BuildingDefinition).cost)
	for res in DefinitionLoader.load_all("res://resources/recipes/"):
		needed.merge((res as CraftingRecipe).inputs)
	for key in needed.keys():
		if not obtainable.has(StringName(key)):
			_fail("item '%s' is needed by a cost/recipe but nothing produces it" % key)


## The audio library: every listed id has at least one variant file,
## every Fx.burst kind has a sound, and the loops are set.
func _validate_audio() -> void:
	var library: AudioLibrary = load("res://resources/audio/audio_library.tres") as AudioLibrary
	if library == null:
		_fail("res://resources/audio/audio_library.tres is missing or not an AudioLibrary")
		return
	for id in library.volumes.keys():
		if library.streams_for(StringName(id)).is_empty():
			_fail("audio id '%s' has no %s/%s_1.ogg" % [id, library.sfx_dir, id])
	for id in library.ui_ids:
		if not library.has_sound(id):
			_fail("audio ui id '%s' is not in volumes" % id)
	for kind in Fx.BURSTS.keys():
		if not library.has_sound(kind) and not Fx.SILENT_BURSTS.has(kind):
			_fail("Fx burst '%s' has no sound in the audio library" % kind)
	for loop_name in ["music_day", "music_night", "ambience_day", "ambience_night", "ambience_campfire"]:
		if library.get(loop_name) == null:
			_fail("audio library has no %s" % loop_name)
	for bus_name in [&"Music", &"SFX", &"UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			_fail("audio bus '%s' missing (default_bus_layout.tres)" % bus_name)


func _check_id(id: StringName, path: String, seen: Dictionary) -> void:
	if id == &"":
		_fail("%s has an empty id" % path)
	elif seen.has(id):
		_fail("%s duplicates id '%s' from %s" % [path, id, seen[id]])
	else:
		seen[id] = path


func _check_scene(scene_path: String, owner_path: String) -> void:
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		_fail("%s points at missing scene '%s'" % [owner_path, scene_path])


func _check_items(costs: Dictionary, item_ids: Dictionary, owner_path: String) -> void:
	for key in costs.keys():
		if not item_ids.has(StringName(key)):
			_fail("%s references unknown item '%s'" % [owner_path, key])
		if int(costs[key]) <= 0:
			_fail("%s has non-positive amount for '%s'" % [owner_path, key])


func _collect(dir_path: String, out: PackedStringArray) -> void:
	if dir_path.trim_suffix("/") in SKIP_DIRS:
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var full: String = dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				_collect(full, out)
		elif name.ends_with(".gd") or name.ends_with(".tscn") or name.ends_with(".tres"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


func _fail(message: String) -> void:
	_errors.append(message)
