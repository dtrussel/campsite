extends Node

## Profile
##
## What a player keeps across runs (see GLOSSARY.md, "Profile"): story
## beats seen, chapters won, records and, later, badges. It lives in its
## own JSON file, user://profile.json, apart from the run save, and a run
## ending never deletes it. Device settings (audio, look, auto-attack)
## are not kept here; they stay in user://settings.cfg, so deleting a
## profile never resets them.
##
## Keys are strings with a dotted prefix by owner ("story.", "chapters.",
## "endless.", "badges."), and values are JSON-friendly (numbers come
## back as floats). Every write is saved straight away. A missing or
## unreadable file loads as an empty profile and is rewritten on the
## next write. Tests point the profile at their own file with set_path.

const PROFILE_PATH: String = "user://profile.json"

var _path: String = PROFILE_PATH
var _data: Dictionary = {}


func _ready() -> void:
	reload()


## Points the profile at another file (tests use a file of their own)
## and loads it.
func set_path(path: String) -> void:
	_path = path
	reload()


## The file the profile reads and writes.
func file_path() -> String:
	return _path


## Reads the profile again from its file; a missing or damaged file
## loads as empty.
func reload() -> void:
	_data = _read(_path)


## The value kept under key, or fallback when there is none.
func get_value(key: String, fallback: Variant = null) -> Variant:
	return _data.get(key, fallback)


## Keeps value under key and saves the profile.
func set_value(key: String, value: Variant) -> void:
	_data[key] = value
	_write()


func has_value(key: String) -> bool:
	return _data.has(key)


## Keeps value under key when it beats the stored number (or none is
## stored yet) and says whether it did, so an end screen can say
## "New record!" from one call. An equal value is not a record.
func record_best(key: String, value: float) -> bool:
	var stored: Variant = _data.get(key)
	if (stored is float or stored is int) and value <= float(stored):
		return false
	set_value(key, value)
	return true


## Empties the profile and removes its file.
func delete() -> void:
	_data = {}
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		PlaytestLog.write("profile_ignored path=%s" % path)
		return {}
	return json.data


func _write() -> void:
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		push_warning("Profile: cannot write %s" % _path)
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()
