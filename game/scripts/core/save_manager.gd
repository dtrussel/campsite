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
## buildings (type, place, HP, construction progress), the party (which
## hero is played, feature 034), both heroes' progress and upgrades, the
## companion's task, run stats, the Moon Lantern's shards (feature 036;
## older saves start it at 0, same VERSION), each hero's perk cards, the
## Ember Heart torches still burning after the dawn (their dawns left and
## radius) and what each blueprint was paid with (perk cards). Not saved:
## resource nodes and pickups (they reset), plain torches (they burn out
## at the dawn the save is made on).
## Every part of the save is written and read by its own saving system
## (run lifecycle 02 and 03): the autoloads (time, the run fields with
## the shard pity counter, resources, progression, perks) and the world
## (campfire, buildings, torches, the Moon Lantern, the heroes). The run
## session gathers them; this file only holds the camp's presence check
## (snapshot) and the file itself.
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


## The save's own part: just the version stamp while a camp is up, {}
## when there is no camp to save. RunSession.snapshot adds every saving
## system's keys; save through that.
func snapshot() -> Dictionary:
	var tree: SceneTree = get_tree()
	var fire: BaseCore = tree.get_first_node_in_group("base_core") as BaseCore
	var player: Node = tree.get_first_node_in_group("player")
	var sibling: Node = tree.get_first_node_in_group("companions")
	if fire == null or player == null or sibling == null:
		return {}
	return {"version": VERSION}


func _on_dawn_started(_day: int) -> void:
	# After every dawn handler (the win check, Nela waking up, torches
	# burning out) has run.
	_autosave.call_deferred()


func _autosave() -> void:
	if GameManager.is_playing():
		save_now()
