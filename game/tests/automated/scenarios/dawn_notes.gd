extends "res://tests/automated/smoke_scenario.gd"

## Mum's dawn notes: the run's own dawn finds each one as a journal
## page, with or without a HUD to show its card.


func run() -> void:
	await _check_note_without_hud()
	await _check_note_with_hud()


## A camp with no HUD still finds the night 2 dawn note.
func _check_note_without_hud() -> void:
	print("smoke: --- dawn notes scenario ---")
	var note: JournalPage = Journal.page_for_note("dawn.c1.n2.note")
	await _start_fresh_run()
	var hud: Node = get_tree().get_first_node_in_group("hud")
	_check(hud != null, "the camp opens with a HUD")
	if hud != null:
		hud.free()
	_check(get_tree().get_first_node_in_group("hud") == null, "the HUD is gone from the scene")
	await _skip_to_dawn(2)
	_check(note != null and Journal.is_found(note.id), "with no HUD, the night 2 dawn finds its note as a journal page")
	await _close_main()


## With the HUD, the dawn card still shows, and the page is found once.
func _check_note_with_hud() -> void:
	Profile.delete()
	var note: JournalPage = Journal.page_for_note("dawn.c1.n2.note")
	var finds: Array[StringName] = []
	var on_found: Callable = func(id: StringName) -> void: finds.append(id)
	Profile.page_found.connect(on_found)
	await _start_fresh_run()
	await _skip_to_dawn(1)
	var hud: Node = get_tree().get_first_node_in_group("hud")
	var first: StoryCard = hud.call("story_card") as StoryCard if hud != null else null
	if first != null:
		first.dismiss()  # so the night 2 card is not queued behind it
	await _skip_to_dawn(2)
	var beat: StoryBeat = StoryLibrary.first(&"dawn", 1, 2)
	var card: StoryCard = hud.call("story_card") as StoryCard if hud != null else null
	_check(card != null and beat != null and card.lines() == beat.lines_for(GameManager.hero_id), "the night 2 dawn card shows on the HUD")
	_check(note != null and finds.count(note.id) == 1, "the dawn note's page is found once (%s)" % [finds])
	Profile.page_found.disconnect(on_found)
	await _close_main()
