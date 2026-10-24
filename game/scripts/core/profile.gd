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
## Callers read and write through its verbs (pages found, beats seen,
## the hero picked, chapters won, the endless best and the unlocks).
## The raw key access (get_value, set_value) is still there for the
## modules that have not moved to verbs yet.
##
## Keys are strings with a dotted prefix by owner ("story.", "chapters.",
## "endless.", "badges."), and values are JSON-friendly (numbers come
## back as floats). Every write is saved straight away. A missing or
## unreadable file loads as an empty profile and is rewritten on the
## next write. Smoke and the screenshot sim point the profile at their
## own file with set_path; unit tests keep it in memory with use_memory.
##
## The keys sit behind a store, the profile's one seam to where they
## are kept: the JSON file (FileStore) or memory (MemoryStore). Both
## hold the same JSON text, so a value reads back the same from either.
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
## The prefix found journal pages are kept under ("journal.ranger_log").
const PAGE_PREFIX: String = "journal."
## The true ending's beat (StoryLibrary.TRUE_ENDING). A profile that
## never recorded Chapter 2 won (one imported from story.cfg) keeps
## Endless through it.
const _TRUE_ENDING: String = "ending.c2"
const _OLD_CHAPTER_2_BEATS: Array[String] = ["intro.c2", _TRUE_ENDING]

var _store: Store = MemoryStore.new()
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
	_store = FileStore.new(path, old_story_path)
	reload()


## Keeps the profile in memory only, starting empty, for unit tests. It
## is never saved and has no old story file to import.
func use_memory() -> void:
	_store = MemoryStore.new()
	reload()


## Reads the profile again from its store; a missing or damaged file
## loads as empty.
func reload() -> void:
	var created: bool = _store.exists()
	_data = _parse(_store.read())
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


## Whether the title lets the player start Endless: once Chapter 2 is
## won, or, for a profile that never recorded that win, once the true
## ending was seen.
func is_endless_unlocked() -> bool:
	return is_chapter_won(2) or has_seen(_TRUE_ENDING)


## Records a chapter won; winning Chapter 1 unlocks Chapter 2.
func record_chapter_won(chapter: int) -> void:
	set_value(chapter_won_key(chapter), true)
	if chapter == 1 and not get_value(CHAPTER_2_UNLOCKED, false):
		set_value(CHAPTER_2_UNLOCKED, true)
		PlaytestLog.write("chapter_unlocked chapter=2")


## Keeps journal page `id` as found. True when it was not found before.
func find_page(id: StringName) -> bool:
	if is_page_found(id):
		return false
	set_value(PAGE_PREFIX + String(id), true)
	return true


## Whether journal page `id` was found (Journal adds the badge pages).
func is_page_found(id: StringName) -> bool:
	return bool(get_value(PAGE_PREFIX + String(id), false))


## Keeps story beat `beat` ("intro.c1") as seen.
func mark_seen(beat: String) -> void:
	set_value(STORY_PREFIX + beat, true)


func has_seen(beat: String) -> bool:
	return bool(get_value(STORY_PREFIX + beat, false))


## Forgets every beat seen, so each plays again.
func forget_seen() -> void:
	forget(STORY_PREFIX)


## Keeps `hero` (a HeroRoster id) as the one picked last on hero select.
func record_hero_pick(hero: StringName) -> void:
	set_value(LAST_HERO, String(hero))


## The hero picked last on hero select, or &"" when none was.
func last_hero_pick() -> StringName:
	return StringName(String(get_value(LAST_HERO, "")))


func is_chapter_won(chapter: int) -> bool:
	return bool(get_value(chapter_won_key(chapter), false))


## An endless run ended on `night` playing `hero`: keeps it as the
## endless best when it reached further than the best so far. True when
## it did (an equal night is not a record).
func record_endless(night: int, hero: StringName) -> bool:
	if not record_best(ENDLESS_BEST_NIGHTS, night):
		return false
	set_value(ENDLESS_BEST_HERO, String(hero))
	return true


## The furthest night an endless run reached, or 0 before the first.
func endless_best_night() -> int:
	return int(get_value(ENDLESS_BEST_NIGHTS, 0))


## The hero who played the endless best, or &"" before the first.
func endless_best_hero() -> StringName:
	return StringName(String(get_value(ENDLESS_BEST_HERO, "")))


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
	_store.remove()
	if imported:
		set_value(OLD_STORY_IMPORTED, true)


func _import_old_story() -> void:
	if _data.has(OLD_STORY_IMPORTED) or not _store.has_old_story():
		return
	for beat in _store.old_seen_beats():
		_data[STORY_PREFIX + beat] = true
		if beat in _OLD_CHAPTER_2_BEATS:
			_data[CHAPTER_2_UNLOCKED] = true
	_data[OLD_STORY_IMPORTED] = true
	_write()
	PlaytestLog.write("profile_imported_story path=%s" % _store.old_story_path)


## The keys in a store's text; empty text (no file) or text that is
## not a JSON object loads as empty.
func _parse(text: String) -> Dictionary:
	if text == "":
		return {}
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		PlaytestLog.write("profile_ignored path=%s" % _store.where())
		return {}
	return json.data


func _write() -> void:
	_store.write(JSON.stringify(_data, "\t"))


## Where the profile's JSON text is kept. The profile reads and writes
## its keys only through these.
class Store:
	extends RefCounted

	## The old story file to import; "" means none.
	var old_story_path: String = ""

	## Whether the profile was ever written here (else it is new).
	func exists() -> bool:
		return false

	## The text kept, or "" when there is none.
	func read() -> String:
		return ""

	func write(_text: String) -> void:
		pass

	func remove() -> void:
		pass

	## Where it is, for the playtest log.
	func where() -> String:
		return "memory"

	## Whether there is an old story file to import.
	func has_old_story() -> bool:
		return false

	## The beats the old story file marks seen.
	func old_seen_beats() -> Array[String]:
		return []


## The game's store: the JSON file at path.
class FileStore:
	extends Store

	var path: String

	func _init(file_path: String, old_story: String) -> void:
		path = file_path
		old_story_path = old_story

	func exists() -> bool:
		return FileAccess.file_exists(path)

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

	func where() -> String:
		return path

	func has_old_story() -> bool:
		return old_story_path != "" and FileAccess.file_exists(old_story_path)

	func old_seen_beats() -> Array[String]:
		var out: Array[String] = []
		var old: ConfigFile = ConfigFile.new()
		if old.load(old_story_path) == OK and old.has_section("seen"):
			for beat in old.get_section_keys("seen"):
				if bool(old.get_value("seen", beat, false)):
					out.append(beat)
		return out


## The unit tests' store: the same text, kept in memory.
class MemoryStore:
	extends Store

	var _text: String = ""
	var _written: bool = false

	func exists() -> bool:
		return _written

	func read() -> String:
		return _text

	func write(text: String) -> void:
		_text = text
		_written = true

	func remove() -> void:
		_text = ""
		_written = false
