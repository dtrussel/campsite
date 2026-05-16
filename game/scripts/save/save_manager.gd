extends Node

## Serializes and deserializes save data to disk.
## All saved data goes into a versioned Dictionary → JSON file.

const SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://save_slot_%d.json"

signal save_completed(slot: int)
signal load_completed(slot: int)

func save_game(slot: int = 0) -> void:
	var data: Dictionary = {
		"save_version": SAVE_VERSION,
		"day": GameManager.current_day,
		"resources": ResourceManager.get_all(),
		"progression": _serialize_progression(),
	}
	var path: String = SAVE_PATH % slot
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		save_completed.emit(slot)
		print("SaveManager: saved to %s" % path)
	else:
		push_error("SaveManager: failed to open '%s' for writing" % path)

func load_game(slot: int = 0) -> bool:
	var path: String = SAVE_PATH % slot
	if not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("SaveManager: failed to open '%s' for reading" % path)
		return false
	var text: String = file.get_as_text()
	file.close()
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		push_error("SaveManager: corrupt save file at '%s'" % path)
		return false
	if data.get("save_version", 0) != SAVE_VERSION:
		push_warning("SaveManager: save version mismatch — data may not load correctly")
	_apply_save(data)
	load_completed.emit(slot)
	return true

func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(SAVE_PATH % slot)

func _serialize_progression() -> Dictionary:
	# Stub: extend when ProgressionManager tracks more characters
	return {}

func _apply_save(data: Dictionary) -> void:
	if data.has("day"):
		GameManager.current_day = data["day"]
	if data.has("resources"):
		var resources: Dictionary = data["resources"]
		for id in resources:
			var current: int = ResourceManager.get_amount(id)
			var saved: int = int(resources[id])
			if saved > current:
				ResourceManager.add(id, saved - current)
			elif saved < current:
				ResourceManager.remove(id, current - saved)
