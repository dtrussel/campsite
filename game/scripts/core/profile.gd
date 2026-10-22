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
##
## The old story file (user://story.cfg, before the profile existed) is
## imported once, the first time a profile that has never been created
## loads: every seen beat becomes a "story.<beat>" key, and a seen
## Chapter 2 intro or true ending sets CHAPTER_2_UNLOCKED (story.cfg
## never recorded a Chapter 1 win, so these stand in for it). The old
## file is left on disk, unused, so a downgrade still works.

const PROFILE_PATH: String = "user://profile.json"
const OLD_STORY_PATH: String = "user://story.cfg"
## The prefix StoryLibrary keeps seen beats under ("story.intro.c1").
const STORY_PREFIX: String = "story."
## True once the player has won Chapter 1 (for the chapter lock), or
## the story.cfg import found Chapter 2 played.
const CHAPTER_2_UNLOCKED: String = "chapters.c2.unlocked"
## The hero last picked on hero select (a HeroRoster id).
const LAST_HERO: String = "heroes.last"
## Endless mode's record: the most nights an endless
## run lasted (the night it ended on), and the hero who did it.
const ENDLESS_BEST_NIGHTS: String = "endless.best_nights"
const ENDLESS_BEST_HERO: String = "endless.best_hero"
## Kept through delete, so the old story file is imported only once and
## deleting a profile really starts the player over.
const OLD_STORY_IMPORTED: String = "profile.story_cfg_imported"
const _OLD_CHAPTER_2_BEATS: Array[String] = ["intro.c2", "ending.c2"]

var _path: String = PROFILE_PATH
var _old_story_path: String = ""
var _data: Dictionary = {}
## Debug builds (the editor, a debug export) and builds exported with
## the "playtest" feature tag open every chapter. Tests clear it to see
## the lock as a player does.
var unlock_all_chapters: bool = OS.is_debug_build() or OS.has_feature("playtest")


func _ready() -> void:
	set_path(PROFILE_PATH, OLD_STORY_PATH)


## Points the profile at another file (tests use a file of their own)
## and loads it. old_story_path is the story.cfg to import when this
## profile has never been created; empty means import nothing.
func set_path(path: String, old_story_path: String = "") -> void:
	_path = path
	_old_story_path = old_story_path
	reload()


## Reads the profile again from its file; a missing or damaged file
## loads as empty.
func reload() -> void:
	var created: bool = FileAccess.file_exists(_path)
	_data = _read(_path)
	if not created:
		_import_old_story()


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


## The key that says chapter was won ("chapters.c1.won").
static func chapter_won_key(chapter: int) -> String:
	return "chapters.c%d.won" % chapter


## Whether the title lets the player start chapter: Chapter 1 always,
## Chapter 2 once Chapter 1 is won (or the story.cfg import found it
## played), and every chapter in debug and playtest builds.
func is_chapter_unlocked(chapter: int) -> bool:
	if chapter <= 1 or unlock_all_chapters:
		return true
	return chapter == 2 and bool(get_value(CHAPTER_2_UNLOCKED, false))


## Records a chapter won; winning Chapter 1 unlocks Chapter 2.
func record_chapter_won(chapter: int) -> void:
	set_value(chapter_won_key(chapter), true)
	if chapter == 1 and not get_value(CHAPTER_2_UNLOCKED, false):
		set_value(CHAPTER_2_UNLOCKED, true)
		PlaytestLog.write("chapter_unlocked chapter=2")


## Removes every key that starts with prefix ("story.") and saves.
func forget(prefix: String) -> void:
	for key in _data.keys():
		if String(key).begins_with(prefix):
			_data.erase(key)
	_write()


## Empties the profile and removes its file. Only the note that the old
## story file was imported survives (in a file holding just that), so
## the import never runs again.
func delete() -> void:
	var imported: bool = _data.has(OLD_STORY_IMPORTED)
	_data = {}
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))
	if imported:
		set_value(OLD_STORY_IMPORTED, true)


func _import_old_story() -> void:
	if _old_story_path == "" or _data.has(OLD_STORY_IMPORTED) or not FileAccess.file_exists(_old_story_path):
		return
	var old: ConfigFile = ConfigFile.new()
	if old.load(_old_story_path) == OK and old.has_section("seen"):
		for beat in old.get_section_keys("seen"):
			if bool(old.get_value("seen", beat, false)):
				_data[STORY_PREFIX + beat] = true
				if beat in _OLD_CHAPTER_2_BEATS:
					_data[CHAPTER_2_UNLOCKED] = true
	_data[OLD_STORY_IMPORTED] = true
	_write()
	PlaytestLog.write("profile_imported_story path=%s" % _old_story_path)


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
