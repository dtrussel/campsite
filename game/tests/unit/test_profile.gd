extends "res://tests/unit/unit_test.gd"

## The profile on its in-memory store: each verb and what it reads
## back, and the Chapter 2 and Endless unlock rules.

const PROFILE_SCRIPT: GDScript = preload("res://scripts/core/profile.gd")

## The profile under test: a fresh one in memory, never the game's.
var profile: Node = PROFILE_SCRIPT.new()


func _init() -> void:
	profile.use_memory()
	profile.unlock_all_chapters = false


func after_each() -> void:
	profile.free()


func test_a_page_found_reads_as_found() -> void:
	check(not profile.is_page_found(&"ranger_log"), "a new profile has no page found")
	check(profile.find_page(&"ranger_log"), "finding a page is new the first time")
	check(profile.is_page_found(&"ranger_log"), "a page found reads as found")
	check(not profile.find_page(&"ranger_log"), "finding a page again is not new")
	check(not profile.is_page_found(&"old_lantern"), "finding one page finds no other")


func test_a_beat_seen_reads_as_seen() -> void:
	check(not profile.has_seen("intro.c1"), "a new profile has seen no beat")
	profile.mark_seen("intro.c1")
	check(profile.has_seen("intro.c1"), "a beat marked seen reads as seen")
	check(not profile.has_seen("intro.c2"), "marking one beat sees no other")
	profile.forget_seen()
	check(not profile.has_seen("intro.c1"), "forgetting the beats leaves none seen")


func test_the_hero_picked_last_reads_back() -> void:
	check_eq(profile.last_hero_pick(), &"", "a new profile has no hero picked")
	profile.record_hero_pick(&"tess")
	check_eq(profile.last_hero_pick(), &"tess", "the hero picked reads back")
	profile.record_hero_pick(&"leo")
	check_eq(profile.last_hero_pick(), &"leo", "a later pick replaces it")


func test_a_chapter_won_reads_as_won() -> void:
	check(not profile.is_chapter_won(1), "a new profile has won no chapter")
	profile.record_chapter_won(1)
	check(profile.is_chapter_won(1), "Chapter 1 won reads as won")
	check(not profile.is_chapter_won(2), "winning Chapter 1 does not win Chapter 2")


func test_chapter_2_unlocks_when_chapter_1_is_won() -> void:
	check(profile.is_chapter_unlocked(1), "Chapter 1 is always unlocked")
	check(not profile.is_chapter_unlocked(2), "Chapter 2 starts locked")
	profile.record_chapter_won(1)
	check(profile.is_chapter_unlocked(2), "winning Chapter 1 unlocks Chapter 2")
	check(not profile.is_chapter_unlocked(3), "no Chapter 3 unlocks")


func test_debug_and_playtest_builds_unlock_every_chapter() -> void:
	profile.unlock_all_chapters = true
	check(profile.is_chapter_unlocked(2), "Chapter 2 is unlocked in a debug build")


func test_endless_unlocks_when_chapter_2_is_won() -> void:
	check(not profile.is_endless_unlocked(), "Endless starts locked")
	profile.record_chapter_won(1)
	check(not profile.is_endless_unlocked(), "winning Chapter 1 does not unlock Endless")
	profile.record_chapter_won(2)
	check(profile.is_endless_unlocked(), "winning Chapter 2 unlocks Endless")


func test_an_old_profile_with_the_true_ending_seen_keeps_endless() -> void:
	profile.mark_seen(StoryLibrary.TRUE_ENDING)
	check(not profile.is_chapter_won(2), "the old profile never recorded Chapter 2 won")
	check(profile.is_endless_unlocked(), "a profile that saw the true ending keeps Endless")


func test_the_endless_best_keeps_the_furthest_night() -> void:
	check_eq(profile.endless_best_night(), 0, "a new profile has no endless best")
	check_eq(profile.endless_best_hero(), &"", "a new profile has no endless best hero")
	check(profile.record_endless(5, &"leo"), "a first endless run is a record")
	check(profile.record_endless(8, &"tess"), "a further night is a record")
	check(not profile.record_endless(6, &"leo"), "a shorter run is not a record")
	check(not profile.record_endless(8, &"leo"), "an equal night is not a record")
	check_eq(profile.endless_best_night(), 8, "the best is the furthest night")
	check_eq(profile.endless_best_hero(), &"tess", "the best hero is the one who reached it")


func test_a_new_profile_has_no_badge_earned() -> void:
	check(not profile.is_badge_earned(&"first_night"), "a new profile has earned no badge")


func test_the_starting_perk_picked_reads_back() -> void:
	check_eq(profile.starting_perk_pick(), &"", "a new profile has no starting perk picked")
	profile.record_starting_perk_pick(&"quick_hands")
	check_eq(profile.starting_perk_pick(), &"quick_hands", "the starting perk picked reads back")
	profile.record_starting_perk_pick(&"")
	check_eq(profile.starting_perk_pick(), &"", "picking none clears it")


func test_each_hero_keeps_their_own_outfit_pick() -> void:
	check_eq(profile.outfit_pick(&"leo"), &"", "a new profile has no outfit picked")
	profile.record_outfit_pick(&"leo", &"moss")
	profile.record_outfit_pick(&"nela", &"ember")
	check_eq(profile.outfit_pick(&"leo"), &"moss", "Leo's outfit pick reads back")
	check_eq(profile.outfit_pick(&"nela"), &"ember", "Nela's outfit pick is her own")


func test_the_tent_picked_reads_back() -> void:
	check_eq(profile.tent_pick(), &"", "a new profile has no tent picked")
	profile.record_tent_pick(&"berry")
	check_eq(profile.tent_pick(), &"berry", "the tent picked reads back")
