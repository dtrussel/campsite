class_name Journal
extends RefCounted

## Journal
##
## Mum's journal: the JournalPage files under
## res://resources/story/journal/ and which of them the player has
## found, kept in the profile for good (Profile.find_page). A page is
## found when its dawn card plays (Mum's dawn notes), when a day
## chest holding it is opened (DayChest), or, for a badge page, as soon
## as its badge is earned (read from the badge, so badges earned before
## the journal existed count too). The scrapbook's Journal tab shows
## the found ones (JournalBook).

const PAGES_DIR: String = "res://resources/story/journal/"

static var _pages: Array[JournalPage] = []


## Every page, in journal order (by file name).
static func pages() -> Array[JournalPage]:
	if _pages.is_empty():
		for res in DefinitionLoader.load_all(PAGES_DIR):
			if res is JournalPage:
				_pages.append(res as JournalPage)
		_pages.sort_custom(func(a: JournalPage, b: JournalPage) -> bool:
			return a.resource_path < b.resource_path)
	return _pages


static func get_page(id: StringName) -> JournalPage:
	for page in pages():
		if page.id == id:
			return page
	return null


## The page that shows the dawn note line `note_id`, or null.
static func page_for_note(note_id: String) -> JournalPage:
	for page in pages():
		if page.found_in == &"dawn" and page.note_id == note_id:
			return page
	return null


static func is_found(id: StringName) -> bool:
	if Profile.is_page_found(id):
		return true
	var page: JournalPage = get_page(id)
	return page != null and page.found_in == &"badge" and Profile.is_badge_earned(page.badge)


## The pages found, in journal order.
static func found() -> Array[JournalPage]:
	var out: Array[JournalPage] = []
	for page in pages():
		if is_found(page.id):
			out.append(page)
	return out


## Keeps page `id` as found. True when it was not found before.
static func find(id: StringName) -> bool:
	if get_page(id) == null or is_found(id):
		return false
	Profile.find_page(id)
	PlaytestLog.write("journal_page_found id=%s" % id)
	return true


## Finds the pages of the dawn notes on `beat` (a dawn card playing).
static func find_notes_on(beat: StoryBeat) -> void:
	if beat == null:
		return
	for line in beat.lines:
		var page: JournalPage = page_for_note(String((line as Dictionary).get("id", "")))
		if page != null:
			find(page.id)


## The page a day chest holds: the first chest page not yet found, else
## the first dawn note not yet found (so a chest still helps once the
## chest pages are all found; badge pages come only from their badge).
## Null when there is none left: then no chest comes.
static func next_chest_page() -> JournalPage:
	var fallback: JournalPage = null
	for page in pages():
		if is_found(page.id):
			continue
		if page.found_in == &"chest":
			return page
		if fallback == null and page.found_in == &"dawn":
			fallback = page
	return fallback
