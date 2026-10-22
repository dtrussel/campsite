extends Node

## SaveManager
##
## The save file itself: its path and
## version, writing and reading it as JSON, the parse checks and delete.
## It knows nothing of what is in a run: every part of the save is
## written and read by its own saving system, and RunSession gathers
## them (RunSession.snapshot), autosaves at dawn and deletes the save
## when a run ends. What a save holds is listed in
## docs/architecture/software-architecture.md.
##
## Saves are versioned: a different version or a damaged file is
## ignored (Continue is hidden), never half-loaded.
## VERSION 2: four resources were cut and
## buildings carry their construction progress, so v1 saves are ignored.
## Later additions (the party, the Moon Lantern's shards, perk cards,
## torches, paid costs, the pity counter) kept VERSION 2: a save without
## them still loads, each saving system filling in a fresh value.

## A save was written; `day` is the day it was made on.
signal saved(day: int)

const SAVE_PATH: String = "user://save.json"
const VERSION: int = 2
## The keys every usable save has (parse rejects a save without one).
const REQUIRED_KEYS: Array[String] = ["nights_to_win", "day", "inventory", "campfire", "buildings", "player", "sibling", "stats"]

var _save_path: String = SAVE_PATH


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


## A snapshot from JSON text, or {} if it is damaged, from another
## version or missing one of REQUIRED_KEYS.
static func parse(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", -1)) != VERSION:
		return {}
	for key in REQUIRED_KEYS:
		if not data.has(key):
			return {}
	return data


## Writes `snapshot` (RunSession.snapshot) to the save file, replacing
## any save there. False when it is empty or cannot be written.
func write(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	var file: FileAccess = FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: cannot write %s" % _save_path)
		return false
	file.store_string(serialize(snapshot))
	file.close()
	var day: int = int(snapshot.get("day", 0))
	PlaytestLog.write("autosaved day=%d" % day)
	saved.emit(day)
	return true
