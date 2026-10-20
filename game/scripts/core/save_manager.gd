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
## buildings (type, place, HP / trap snaps, construction progress), the party (which hero is
## played, feature 034), both heroes' progress and upgrades, the
## companion's task, run stats, the Moon Lantern's shards (feature 036;
## older saves start it at 0, same VERSION). Not saved: resource nodes and
## pickups (they reset), torches (they burn out at dawn anyway).
## VERSION 2 (playtest 1, feature 044): four resources were cut and
## buildings carry their construction progress, so v1 saves are ignored.

signal saved(day: int)

const SAVE_PATH: String = "user://save.json"
const VERSION: int = 2

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


## The party a save was made with: {"hero", "companion"} as ids. Saves
## from before feature 034 are Leo with Nela.
static func party_of(data: Dictionary) -> Dictionary:
	var party: Dictionary = data.get("party", {}) if data.get("party") is Dictionary else {}
	return {
		"hero": StringName(str(party.get("hero", "leo"))),
		"companion": StringName(str(party.get("companion", "nela"))),
	}


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
			"progress": building.build_progress,
		})
	var lantern: MoonLantern = MoonLantern.find(tree)
	var stats: Dictionary = {}
	for key in GameManager.stats.keys():
		stats[String(key)] = GameManager.stats[key]
	return {
		"nights_to_win": GameManager.nights_to_win,
		"day": TimeManager.day_number,
		"inventory": inventory,
		"campfire": {"hp": fire.current_hp, "hearth": fire.has_hearth},
		"buildings": buildings,
		"party": {"hero": String(GameManager.hero_id), "companion": String(GameManager.companion_id)},
		"player": {
			"xp": ProgressionManager.get_xp(player),
			"signature": bool(player.get("has_signature")),
			"perks": _perk_ids(player),
		},
		"sibling": {
			"xp": ProgressionManager.get_xp(sibling),
			"signature": bool(sibling.get("has_signature")),
			"task": int(sibling.get("current_task")),
			"perks": _perk_ids(sibling),
		},
		"stats": stats,
		"lantern": {"shards": lantern.shards if lantern != null else 0},
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
		var progress: float = float(entry.get("progress", 1.0))
		if progress < 1.0:
			building.set_meta(&"blueprint", true)
			building.set_meta(&"blueprint_progress", progress)
		tree.current_scene.add_child(building)
		var pos: Array = entry["pos"]
		building.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		building.global_rotation.y = float(entry.get("yaw", 0.0))
		if progress >= 1.0:
			building.current_hp = clampi(int(entry["hp"]), 1, definition.max_hp)
			building.call("_refresh_hp_label")
	var player: Node = tree.get_first_node_in_group("player")
	var sibling: Node = tree.get_first_node_in_group("companions")
	ProgressionManager.restore_xp(player, int(data["player"]["xp"]))
	ProgressionManager.restore_xp(sibling, int(data["sibling"]["xp"]))
	# Saves from before perk cards have no "perks": the heroes hold none.
	PerkManager.restore(player, _saved_perks(data["player"]))
	PerkManager.restore(sibling, _saved_perks(data["sibling"]))
	# Saves from before feature 034 name the upgrades "stick" / "slingshot".
	if bool(data["player"].get("signature", data["player"].get("stick", false))):
		player.call("apply_signature")
	if bool(data["sibling"].get("signature", data["sibling"].get("slingshot", false))):
		sibling.call("apply_signature")
	sibling.call("set_task", int(data["sibling"].get("task", 0)))
	for key in data["stats"].keys():
		GameManager.stats[StringName(key)] = int(data["stats"][key])
	var lantern: MoonLantern = MoonLantern.find(tree)
	if lantern != null:
		var saved: Variant = data.get("lantern", {})
		lantern.restore(int((saved as Dictionary).get("shards", 0)) if saved is Dictionary else 0)


## A hero's taken perk ids as strings, one per copy, in the order taken.
func _perk_ids(character: Node) -> Array:
	return PerkManager.perks_of(character).map(func(id: StringName) -> String: return String(id))


func _saved_perks(hero: Dictionary) -> Array:
	var saved: Variant = hero.get("perks", [])
	return saved if saved is Array else []


func _on_dawn_started(_day: int) -> void:
	# After every dawn handler (the win check, Nela waking up, torches
	# burning out) has run.
	_autosave.call_deferred()


func _autosave() -> void:
	if GameManager.is_playing():
		save_now()
