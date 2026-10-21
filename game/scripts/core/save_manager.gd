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
## older saves start it at 0, same VERSION), each hero's perk cards, the
## Ember Heart torches still burning after the dawn (their dawns left and
## radius) and what each blueprint was paid with (perk cards). Not saved:
## resource nodes and pickups (they reset), plain torches (they burn out
## at the dawn the save is made on).
## The run session gathers the save: the autoloads (time, the run fields
## with the shard pity counter, resources, progression, perks) save
## their own keys; this file still writes the world's part (snapshot).
## VERSION 2 (playtest 1, feature 044): four resources were cut and
## buildings carry their construction progress, so v1 saves are ignored.

signal saved(day: int)

const SAVE_PATH: String = "user://save.json"
const VERSION: int = 2
const TORCH_SCENE: String = "res://scenes/buildings/Torch.tscn"

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
	var snapshot: Dictionary = RunSession.snapshot()
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


## The camp as plain data (ints, floats, strings, arrays, dictionaries):
## the part not yet saved by a saving system. RunSession.snapshot adds
## theirs; save through that.
func snapshot() -> Dictionary:
	var tree: SceneTree = get_tree()
	var fire: BaseCore = tree.get_first_node_in_group("base_core") as BaseCore
	var player: Node = tree.get_first_node_in_group("player")
	var sibling: Node = tree.get_first_node_in_group("companions")
	if fire == null or player == null or sibling == null:
		return {}
	var buildings: Array = []
	for node in tree.get_nodes_in_group(Building.BUILDINGS_GROUP):
		var building: Building = node as Building
		if building == null or building.definition == null or building.current_hp <= 0:
			continue
		var p: Vector3 = building.global_position
		var entry: Dictionary = {
			"id": String(building.definition.id),
			"pos": [p.x, p.y, p.z],
			"yaw": building.global_rotation.y,
			"hp": building.current_hp,
			"progress": building.build_progress,
		}
		if building.is_blueprint() and building.has_meta(BuildManager.PAID_COST_META):
			var paid: Dictionary = {}
			var cost: Dictionary = building.get_meta(BuildManager.PAID_COST_META)
			for id in cost.keys():
				paid[String(id)] = int(cost[id])
			entry["paid"] = paid
		buildings.append(entry)
	var lantern: MoonLantern = MoonLantern.find(tree)
	return {
		"campfire": {"hp": fire.current_hp, "hearth": fire.has_hearth},
		"buildings": buildings,
		"player": {
			"signature": bool(player.get("has_signature")),
		},
		"sibling": {
			"signature": bool(sibling.get("has_signature")),
			"task": int(sibling.get("current_task")),
		},
		"lantern": {"shards": lantern.shards if lantern != null else 0},
		"torches": _torches(tree),
	}


## Rebuilds the camp from a snapshot. Called by RunSession.restore_pending
## once the gameplay scene is ready, before the clock starts.
func apply(data: Dictionary) -> void:
	var tree: SceneTree = get_tree()
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
			# Saves from before perk cards have no "paid": the refund falls
			# back to BuildManager.cost_of.
			if entry.get("paid") is Dictionary:
				var paid: Dictionary = {}
				for id in (entry["paid"] as Dictionary).keys():
					paid[StringName(id)] = int(entry["paid"][id])
				building.set_meta(BuildManager.PAID_COST_META, paid)
		tree.current_scene.add_child(building)
		var pos: Array = entry["pos"]
		building.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		building.global_rotation.y = float(entry.get("yaw", 0.0))
		if progress >= 1.0:
			building.current_hp = clampi(int(entry["hp"]), 1, definition.max_hp)
			building.call("_refresh_hp_label")
	var player: Node = tree.get_first_node_in_group("player")
	var sibling: Node = tree.get_first_node_in_group("companions")
	# Saves from before feature 034 name the upgrades "stick" / "slingshot".
	if bool(data["player"].get("signature", data["player"].get("stick", false))):
		player.call("apply_signature")
	if bool(data["sibling"].get("signature", data["sibling"].get("slingshot", false))):
		sibling.call("apply_signature")
	sibling.call("set_task", int(data["sibling"].get("task", 0)))
	var lantern: MoonLantern = MoonLantern.find(tree)
	if lantern != null:
		var saved: Variant = data.get("lantern", {})
		lantern.restore(int((saved as Dictionary).get("shards", 0)) if saved is Dictionary else 0)
	var torches: Variant = data.get("torches", [])
	if torches is Array:
		_restore_torches(tree, torches)


## The planted torches still burning, as {pos, dawns, radius}. A Glow
## Lantern's aura (same script, inside its building) never burns out and
## is rebuilt with its building.
func _torches(tree: SceneTree) -> Array:
	var out: Array = []
	for node in tree.get_nodes_in_group("torches"):
		var torch: Node3D = node as Node3D
		if torch == null or torch.get_parent() != tree.current_scene or not bool(torch.get("burns_out_at_dawn")):
			continue
		var p: Vector3 = torch.global_position
		out.append({"pos": [p.x, p.y, p.z], "dawns": int(torch.get("dawns_to_burn")), "radius": float(torch.get("radius"))})
	return out


func _restore_torches(tree: SceneTree, torches: Array) -> void:
	var scene: PackedScene = load(TORCH_SCENE) as PackedScene
	for entry in torches:
		if not entry is Dictionary or int(entry.get("dawns", 0)) <= 0:
			continue
		var torch: Node3D = scene.instantiate() as Node3D
		tree.current_scene.add_child(torch)
		var pos: Array = entry["pos"]
		torch.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		torch.set("dawns_to_burn", int(entry["dawns"]))
		torch.call("set_radius", float(entry.get("radius", torch.get("radius"))))


func _on_dawn_started(_day: int) -> void:
	# After every dawn handler (the win check, Nela waking up, torches
	# burning out) has run.
	_autosave.call_deferred()


func _autosave() -> void:
	if GameManager.is_playing():
		save_now()
