extends "res://tests/unit/unit_test.gd"

## The profile on its JSON file: the round trip, a missing or corrupt
## file, the one-time import of the old story file, delete, and a
## profile written before the verbs reading back the same. Each test
## uses its own files under user:// and removes them after.

const PROFILE_SCRIPT: GDScript = preload("res://scripts/core/profile.gd")
const PATH: String = "user://unit_profile.json"
const OLD_STORY_PATH: String = "user://unit_story.cfg"
## A profile file as the game wrote it before the profile had verbs:
## every kind of key, with Chapter 1 won and an endless best of night 9.
const BEFORE_VERBS_FIXTURE: String = "res://tests/fixtures/profile_before_verbs.json"

var profile: Node = PROFILE_SCRIPT.new()


func _init() -> void:
	_remove(PATH)
	_remove(OLD_STORY_PATH)
	profile.unlock_all_chapters = false


func after_each() -> void:
	profile.free()
	_remove(PATH)
	_remove(OLD_STORY_PATH)


func test_a_missing_file_loads_empty() -> void:
	profile.set_path(PATH)
	check_eq(profile.tent_pick(), &"", "a missing file has no tent picked")
	check_eq(profile.endless_best_night(), 0, "nor an endless best")
	check(not FileAccess.file_exists(PATH), "loading a missing file does not write one")


func test_keys_survive_a_reload() -> void:
	profile.set_path(PATH)
	profile.record_tent_pick(&"moon")
	profile.find_page(&"ranger_log")
	profile.record_endless(9, &"leo")
	profile.reload()
	check_eq(profile.tent_pick(), &"moon", "a string survives a reload")
	check(profile.is_page_found(&"ranger_log"), "a page found survives a reload")
	check_eq(profile.endless_best_night(), 9, "the endless best survives a reload")
	check_eq(profile.endless_best_hero(), &"leo", "the endless best hero survives a reload")


func test_a_corrupt_file_loads_empty_and_is_rewritten() -> void:
	_write_text(PATH, "{ not json [")
	profile.set_path(PATH)
	check_eq(profile.tent_pick(), &"", "a corrupt file loads as empty")
	profile.record_tent_pick(&"sun")
	profile.reload()
	check_eq(profile.tent_pick(), &"sun", "a corrupt file is rewritten on the next write")


func test_delete_removes_the_keys_and_the_file() -> void:
	profile.set_path(PATH)
	profile.record_tent_pick(&"moon")
	profile.delete()
	check_eq(profile.tent_pick(), &"", "delete empties the profile")
	check(not FileAccess.file_exists(PATH), "delete removes the file")
	profile.reload()
	check_eq(profile.tent_pick(), &"", "deleted keys stay gone after a reload")


func test_the_old_story_file_is_imported_once() -> void:
	_write_old_story(["intro.c1"])
	profile.set_path(PATH, OLD_STORY_PATH)
	check(profile.has_seen("intro.c1"), "the imported intro.c1 reads as seen")
	check(not profile.has_seen("intro.c2"), "a beat the old file did not see reads as unseen")
	check(not profile.is_chapter_unlocked(2), "a seen intro.c1 alone does not unlock Chapter 2")
	_write_old_story(["intro.c1", StoryLibrary.TRUE_ENDING])
	profile.set_path(PATH, OLD_STORY_PATH)
	check(not profile.has_seen(StoryLibrary.TRUE_ENDING), "a profile already made does not import again")
	check(FileAccess.file_exists(OLD_STORY_PATH), "the import leaves the old story file on disk")


func test_a_seen_chapter_2_beat_in_the_old_story_file_unlocks_chapter_2() -> void:
	for seen in [["intro.c1", "intro.c2"], [StoryLibrary.TRUE_ENDING]]:
		_remove(PATH)
		_write_old_story(seen)
		profile.set_path(PATH, OLD_STORY_PATH)
		for beat in seen:
			check(profile.has_seen(beat), "the imported %s reads as seen" % beat)
		check(profile.is_chapter_unlocked(2), "a seen %s unlocks Chapter 2" % seen[-1])
	check(profile.is_endless_unlocked(), "an imported true ending keeps Endless")


func test_delete_keeps_the_import_note() -> void:
	_write_old_story([StoryLibrary.TRUE_ENDING])
	profile.set_path(PATH, OLD_STORY_PATH)
	profile.delete()
	profile.set_path(PATH, OLD_STORY_PATH)  # as on the next launch
	check(not profile.has_seen(StoryLibrary.TRUE_ENDING), "the old story file is not imported again after delete")
	check(not profile.is_chapter_unlocked(2), "delete starts the player over")


func test_a_profile_from_before_the_verbs_reads_back_the_same() -> void:
	var before: String = FileAccess.get_file_as_string(BEFORE_VERBS_FIXTURE)
	_write_text(PATH, before)
	profile.set_path(PATH)
	check(profile.is_page_found(&"ranger_log"), "its page found reads as found")
	check(profile.has_seen("intro.c2"), "its beat seen reads as seen")
	check(profile.is_chapter_won(1), "its Chapter 1 win reads as won")
	check(not profile.is_chapter_won(2), "it has not won Chapter 2")
	check(profile.is_chapter_unlocked(2), "its Chapter 2 reads as unlocked")
	check(not profile.is_endless_unlocked(), "its Endless stays locked")
	check_eq(profile.last_hero_pick(), &"tess", "its last hero reads back")
	check_eq(profile.endless_best_night(), 9, "its endless best night reads back")
	check_eq(profile.endless_best_hero(), &"leo", "its endless best hero reads back")
	check(profile.is_badge_earned(&"first_night"), "its badge earned reads as earned")
	check(not profile.is_badge_earned(&"builder"), "a badge it never earned reads as not earned")
	check_eq(profile.tent_pick(), &"moss", "its tent pick reads back")
	check(profile.has_won_with(&"leo") and not profile.has_won_with(&"nela"), "its hero won with reads back")
	check_eq(profile.stat_total(&"mobs_defeated"), 41, "its stat total reads back")
	check_eq(profile.starting_perk_pick(), &"", "its empty starting perk pick reads as none")
	# The verbs write the keys it already holds, so its bytes stay the same.
	profile.find_page(&"ranger_log")
	profile.mark_seen("intro.c1")
	profile.record_hero_pick(&"tess")
	profile.record_chapter_won(1)
	profile.record_tent_pick(&"moss")
	profile.record_starting_perk_pick(&"")
	check_eq(FileAccess.get_file_as_string(PATH), before, "writing the same facts again keeps the file byte for byte")


func _write_old_story(seen: Array) -> void:
	var old: ConfigFile = ConfigFile.new()
	for beat in seen:
		old.set_value("seen", beat, true)
	old.save(OLD_STORY_PATH)


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
