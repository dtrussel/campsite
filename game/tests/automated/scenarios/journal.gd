extends "res://tests/automated/smoke_scenario.gd"

## Mum's journal: the day chest, the pages and where they are found,
## and the scrapbook's Journal tab.


func run() -> void:
	await _run_journal_scenario()


## A day chest at the map edge gives a page of Mum's
## journal not yet found, and the scrapbook's Journal tab shows it. A
## run rolls at most one chest (half of them none); a continued run
## never brings a second one. Mum's dawn notes and some badges give
## pages too.
func _run_journal_scenario() -> void:
	print("smoke: --- journal scenario ---")
	Profile.delete()
	var pages: Array[JournalPage] = Journal.pages()
	_check(pages.size() >= 10 and pages.size() <= 12, "Mum's journal has 10-12 pages (%d)" % pages.size())
	_check(Journal.found().is_empty(), "a fresh profile has found no journal page")
	var with_chest: int = 0
	var days_ok: bool = true
	for i in 400:
		var rolled: RunConfig = RunConfig.current()
		if rolled.day_chest_day > 0:
			with_chest += 1
			days_ok = days_ok and rolled.day_chest_day <= rolled.nights_to_win
	_check(with_chest > 140 and with_chest < 260 and days_ok,
		"about half the runs roll a day chest, on one of their days (%d of 400)" % with_chest)

	var chests: Array[Node] = []
	var on_added: Callable = func(node: Node) -> void:
		if node is DayChest:
			chests.append(node)
	get_tree().node_added.connect(on_added)
	var config: RunConfig = _config()
	config.hero_id = &"leo"
	config.companion_id = &"nela"
	config.nights_to_win = 3
	config.endless = false
	config.day_chest_day = 2
	await _start_fresh_run(config)
	_check(chests.is_empty(), "no chest on day 1 when the run's chest comes on day 2")
	await _skip_to_dawn(1)
	var c1_note: JournalPage = Journal.page_for_note("dawn.c1.n2.note")
	_check(c1_note != null and not Journal.is_found(c1_note.id), "the C1 night 2 note is not found before its dawn")
	# Continue from the dawn autosave: the save keeps the run's chest day.
	var data: Dictionary = SaveManager.parse(SaveManager.serialize(RunSession.snapshot()))
	var other: RunConfig = _config()
	other.day_chest_day = 1
	await _continue_from(data, other)
	for i in 60:  # the chest is placed as day 2 starts
		if not chests.is_empty():
			break
		await get_tree().process_frame
	_check(chests.size() == 1, "day 2 brings the run's one day chest (%d)" % chests.size())
	var chest: DayChest = chests[0] as DayChest if not chests.is_empty() else null
	if chest != null:
		var spot: Vector2 = Vector2(chest.global_position.x, chest.global_position.z)
		_check(spot.length() > WorldLayout.CAMP_RADIUS * 2.0, "the chest stands out at the map edge (%.1f m out)" % spot.length())
		var page: JournalPage = Journal.get_page(chest.page_id)
		_check(page != null and page.found_in == &"chest" and not Journal.is_found(page.id),
			"the chest holds a page not yet found")
		var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
		player.global_position = chest.global_position + Vector3(0.6, 0, 0)
		for i in 120:
			if chest.is_opened():
				break
			await get_tree().physics_frame
		_check(chest.is_opened() and Journal.is_found(page.id), "walking up to the chest opens it and finds its page")
		var toasted: bool = false
		for toast in get_tree().get_first_node_in_group("hud").call("toasts"):
			toasted = toasted or (toast as HudToast).text().contains(page.title)
		_check(toasted, "a toast names the page found")
		Profile.reload()
		_check(Journal.is_found(page.id), "the page is kept in the profile, after a restart too")
	await _skip_to_dawn(2)
	_check(c1_note != null and Journal.is_found(c1_note.id), "the dawn card's note is found as a journal page too")
	await _skip_to_dawn(3)
	_check(GameManager.run_state == GameManager.RunState.WON, "the journal run is won")
	_check(chests.size() == 1, "no more than one chest spawns in a run, Continue included (%d)" % chests.size())
	config = _config()
	await _start_fresh_run(config)
	await _skip_to_dawn(2)
	_check(chests.size() == 1, "a run that rolled no chest has none")
	get_tree().node_added.disconnect(on_added)
	await _close_main()

	# Some badges give pages too.
	var badge_page: JournalPage = null
	for candidate in pages:
		if candidate.found_in == &"badge":
			badge_page = candidate
	_check(badge_page != null and not Journal.is_found(badge_page.id), "a badge page is not found before its badge")
	if badge_page != null:
		Profile.set_value(Badges.EARNED_PREFIX + String(badge_page.badge), true)
		_check(Journal.is_found(badge_page.id), "earning %s finds its journal page" % badge_page.badge)

	# The scrapbook's Journal tab shows the pages found.
	var title: Control = (load("res://scenes/ui/TitleScreen.tscn") as PackedScene).instantiate()
	add_child(title)
	await get_tree().process_frame
	(title.call("journal_button") as Button).pressed.emit()
	await get_tree().process_frame
	var book: Control = title.call("scrapbook") as Control
	if book != null:
		book.call("show_tab", "Journal")
		await get_tree().process_frame
		_check(book.call("current_tab") == "Journal", "the scrapbook has a Journal tab")
		var shown: Array = book.call("journal_pages")
		var found_ids: Array = []
		for found_page in Journal.found():
			found_ids.append(found_page.id)
		_check(shown == found_ids and shown.size() == 3, "the Journal tab lists the pages found (%s)" % [shown])
		var chest_page: JournalPage = null
		for found_page in Journal.found():
			if found_page.found_in == &"chest":
				chest_page = found_page
		book.call("show_page", chest_page.id if chest_page != null else &"")
		var text: String = book.call("page_text")
		_check(chest_page != null and text.contains(chest_page.text()), "the Journal tab shows the chest's page")
		var hidden: String = ""
		for candidate in pages:
			if not Journal.is_found(candidate.id):
				hidden = candidate.text()
		_check(hidden != "" and not book.call("all_text").contains(hidden), "a page not yet found can't be read")
	else:
		_fail("the scrapbook opens for the Journal tab")
	title.free()
	Profile.delete()
