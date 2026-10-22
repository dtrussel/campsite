# 04: Journal pages and the day chest

Status: done
Blocked by: 03

**What to build:** 10–12 short pages by Mum, which include the dawn notes (from 046), plus new ones, kept in the profile. A day chest appears at the map edge (at most one per run, 50% chance), and opening it gives a page not yet found. Some badges give pages too. The scrapbook's Journal tab shows the pages found, in a book frame (a placeholder until the art arrives).

- [x] Smoke: a day chest gives a page, and the page shows in the Journal tab.
- [x] Smoke: no more than one chest spawns in a run.
- [x] Screenshot: the Journal tab.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, done:** built test-first; the smoke `journal scenario` covers every box above (it passes with `SMOKE_FRAME_DELAY=40` too).
  - 12 pages as `JournalPage` data (`scripts/story/journal_page.gd`, `resources/story/journal/NN_id.tres`, file order is journal order): the 7 dawn notes (046) plus 3 chest pages (Ranger's log, The rangers' map, Lost and found) and 2 badge pages (Little collectors / Gremlin Catcher, Moonlight / Lantern Lighter). A dawn page names its note line (`note_id`) and reads its text, face and sketch from it, so the dawn card stays the source. The new words are in `story.md` ("Mum's journal").
  - `Journal` (`scripts/meta/journal.gd`, static, no autoload) keeps found pages as `journal.<id>` in the profile. A dawn page is found when its card plays (`hud.gd` calls `Journal.find_notes_on`); a badge page reads as found whenever its badge is earned, so badges earned before this ticket count.
  - Day chest: `RunConfig.day_chest_day` is rolled by `current()` (50%, one of the run's days, else 0). `GameManager.day_chest_day` holds it and saves it (old saves read 0), so Continue never rolls a second chest. On that `day_started`, `DayChest.place` (`scripts/world/day_chest.gd`) puts it beside one of the four lanes ~17.5 m out, with a HUD banner; walking up opens it (like a pickup), finds `Journal.next_chest_page()` (first chest page, then first dawn note not found; no chest when none is left) and toasts the page title. Unopened, it fades at nightfall. No collision; the model is the Storage Crate's chest plus a moonlit light until there's art.
  - Journal tab: `JournalBook` (`scripts/ui/journal_book.gd`), added by `Scrapbook._ready`. A placeholder book frame: a leather cover, the list of 12 pages on the left (unfound ones as "? ? ?" with how they're found in the tooltip), the open page on the notebook paper on the right (Mum's face, her words in quotes, the sketch). Screenshot `01a_scrapbook_journal`, copied to `docs/design/screenshots/journal-scrapbook-journal.png`.
  - The validator's `_validate_journal` checks each page (`JournalPage.problems()`), 10-12 pages, at least one chest page, and that every dawn note is on a page.
  - The smoke `_config()` helper now sets `day_chest_day = 0`, so other scenarios never meet a chest by chance.
  - Not done: a screenshot of the chest in the camp (the ticket asks only for the tab); the chest's look needs a hand-play check.
