class_name ProfileFileStore
extends RefCounted

## ProfileFileStore
##
## The game's profile store (Profile.set_path): the profile's JSON text
## in the file at `path`. It also reads the old story file (story.cfg,
## from before the profile existed) for the profile's one-time import.

var path: String
## The old story file to import; "" means none.
var old_story_path: String


func _init(file_path: String, old_story: String) -> void:
	path = file_path
	old_story_path = old_story


## Whether the profile was ever written here (else it is new).
func exists() -> bool:
	return FileAccess.file_exists(path)


## The text kept, or "" when there is none.
func read() -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ) if exists() else null
	return file.get_as_text() if file != null else ""


func write(text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Profile: cannot write %s" % path)
		return
	file.store_string(text)
	file.close()


func remove() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Where it is, for the playtest log.
func where() -> String:
	return path


## Whether there is an old story file to import.
func has_old_story() -> bool:
	return old_story_path != "" and FileAccess.file_exists(old_story_path)


## The beats the old story file marks seen.
func old_seen_beats() -> Array[String]:
	var out: Array[String] = []
	var old: ConfigFile = ConfigFile.new()
	if old.load(old_story_path) == OK and old.has_section("seen"):
		for beat in old.get_section_keys("seen"):
			if bool(old.get_value("seen", beat, false)):
				out.append(beat)
	return out
