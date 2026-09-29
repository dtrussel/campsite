extends Node

## SaveManager
##
## Autosave at dawn (feature 020). Every morning of a run in progress,
## the camp is written to user://save.json; the title screen then
## offers Continue, which rebuilds the camp and starts at the next
## morning. Saves are versioned: a different version or a damaged file
## is ignored (Continue is hidden), never half-loaded. A won or lost run
## deletes its save, and a new run replaces it.
##
## Saved: run length and day, inventory, campfire (HP, hearth),
## buildings (type, place, HP / trap snaps), Leo's and Nela's progress
## and upgrades, Nela's task, run stats. Not saved: resource nodes and
## pickups (they reset), torches (they burn out at dawn anyway).

signal saved(day: int)

const SAVE_PATH: String = "user://save.json"
const VERSION: int = 1

var _save_path: String = SAVE_PATH


func _ready() -> void:
	TimeManager.dawn_started.connect(_on_dawn_started)
	GameManager.run_ended.connect(func(_won: bool, _reason: String) -> void: delete_save())


## Lets tests write somewhere else.
func set_save_path(path: String) -> void:
	_save_path = path


func has_save() -> bool:
	return not load_save().is_empty()


## The parsed save, or {} when there is none or it cannot be used.
func load_save() -> Dictionary:
	if not FileAccess.file_exists(_save_path):
		return {}
	var file: FileAccess = FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		return {}
	var data: Dictionary = parse(file.get_as_text())
	if data.is_empty():
		PlaytestLog.write("save_ignored path=%s" % _save_path)
	return data


func delete_save() -> void:
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))


## JSON text for a snapshot (stamps the version).
static func serialize(snapshot: Dictionary) -> String:
	var data: Dictionary = snapshot.duplicate(true)
	data["version"] = VERSION
	return JSON.stringify(data, "\t")


## A snapshot from JSON text, or {} if it is damaged or from another
## version.
static func parse(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", -1)) != VERSION:
		return {}
	for key in ["nights_to_win", "day", "inventory", "campfire", "buildings", "player", "sibling", "stats"]:
		if not data.has(key):
			return {}
	return data


## Writes the current camp now (the dawn autosave calls this).
func save_now() -> bool:
	var snapshot: Dictionary = snapshot()
	if snapshot.is_empty():
		return false
	var file: FileAccess = FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: cannot write %s" % _save_path)
		return false
	file.store_string(serialize(snapshot))
	file.close()
	PlaytestLog.write("autosaved day=%d" % TimeManager.day_number)
	saved.emit(TimeManager.day_number)
	return true


## The camp as plain data (ints, floats, strings, arrays, dictionaries).
func snapshot() -> Dictionary:
	var tree: SceneTree = get_tree()
	var fire: BaseCore = tree.get_first_node_in_group("base_core") as BaseCore
	var player: Node = tree.get_first_node_in_group("player")
	var sibling: Node = tree.get_first_node_in_group("companions")
	if fire == null or player == null or sibling == null:
		return {}
	var inventory: Dictionary = {}
	for definition in ResourceManager.get_definitions():
		var count: int = ResourceManager.get_count(definition.id)
		if count > 0:
			inventory[String(definition.id)] = count
	var buildings: Array = []
	for node in tree.get_nodes_in_group(Building.BUILDINGS_GROUP):
		var building: Building = node as Building
		if building == null or building.definition == null or building.current_hp <= 0:
			continue
		var p: Vector3 = building.global_position
		buildings.append({
			"id": String(building.definition.id),
			"pos": [p.x, p.y, p.z],
			"yaw": building.global_rotation.y,
			"hp": building.current_hp,
		})
	var stats: Dictionary = {}
	for key in GameManager.stats.keys():
		stats[String(key)] = GameManager.stats[key]
	return {
		"nights_to_win": GameManager.nights_to_win,
		"day": TimeManager.day_number,
		"inventory": inventory,
		"campfire": {"hp": fire.current_hp, "hearth": fire.has_hearth},
		"buildings": buildings,
		"player": {
			"xp": ProgressionManager.get_xp(player),
			"stick": bool(player.get("has_sturdy_stick")),
		},
		"sibling": {
			"xp": ProgressionManager.get_xp(sibling),
			"slingshot": bool(sibling.get("has_slingshot")),
			"task": int(sibling.get("current_task")),
		},
		"stats": stats,
	}


## Rebuilds the camp from a snapshot. Called by GameManager once the
## gameplay scene is ready, before the clock starts.
func apply(data: Dictionary) -> void:
	var tree: SceneTree = get_tree()
	for key in data["inventory"].keys():
		ResourceManager.add(StringName(key), int(data["inventory"][key]))
	var fire: BaseCore = tree.get_first_node_in_group("base_core") as BaseCore
	if fire != null:
		if bool(data["campfire"].get("hearth", false)):
			fire.build_hearth()
		fire.current_hp = clampi(int(data["campfire"]["hp"]), 1, fire.max_hp)
		fire.call("_refresh_hp_label")
	for entry in data["buildings"]:
		var definition: BuildingDefinition = BuildManager.get_definition(StringName(entry["id"]))
		if definition == null or definition.get_scene() == null:
			continue
		var building: Building = definition.get_scene().instantiate() as Building
		tree.current_scene.add_child(building)
		var pos: Array = entry["pos"]
		building.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		building.global_rotation.y = float(entry.get("yaw", 0.0))
		building.current_hp = clampi(int(entry["hp"]), 1, definition.max_hp)
		building.call("_refresh_hp_label")
	var player: Node = tree.get_first_node_in_group("player")
	var sibling: Node = tree.get_first_node_in_group("companions")
	ProgressionManager.restore_xp(player, int(data["player"]["xp"]))
	ProgressionManager.restore_xp(sibling, int(data["sibling"]["xp"]))
	if bool(data["player"].get("stick", false)):
		player.call("upgrade_stick")
	if bool(data["sibling"].get("slingshot", false)):
		sibling.call("give_slingshot")
	sibling.call("set_task", int(data["sibling"].get("task", 0)))
	for key in data["stats"].keys():
		GameManager.stats[StringName(key)] = int(data["stats"][key])


func _on_dawn_started(_day: int) -> void:
	# After every dawn handler (the win check, Nela waking up, torches
	# burning out) has run.
	_autosave.call_deferred()


func _autosave() -> void:
	if GameManager.is_playing():
		save_now()
