# 07: Screenshots and docs

Status: done
Blocked by: 04, 05, 06

**What to build:** the feature's wrap-up: the title screenshots with Chapter 2 locked and unlocked, the docs updated (game design spec, `story.md` for the journal pages), and journal and badges (041) set to done in the roadmap.

- [x] Screenshots: the title with Chapter 2 locked and unlocked.
- [x] `docs/` updated, and a hand-play check of the scrapbook with a kid added to `.scratch/hand-play-backlog/`.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, done:** the feature's wrap-up; the spec and every ticket are done.
  - **Screenshots.** `screenshots.gd` now shoots `01_title_chapter2_locked` (an empty profile with `Profile.unlock_all_chapters` cleared, as in a release build, since the editor is a debug build that opens every chapter) and `01_title_chapter2_unlocked` (after `Profile.record_chapter_won(1)`), right after the scrapbook shots. Rendered under `xvfb-run` with OpenGL at 1280&times;720 and copied to `docs/design/screenshots/journal-title-chapter2-locked.png` and `journal-title-chapter2-unlocked.png`.
  - **Docs.** A "Ranger's Journal and Camp Badges (feature 041)" section in the game design spec: the chapter lock, last hero, the 15 badges, journal pages and the day chest, the scrapbook, cosmetic tints, starting perks and Delete profile, with the four screenshots. The architecture doc lists the `Badges` autoload, the chapter lock and Delete profile under Profile, and a new "Journal, scrapbook and unlocks" section (`Journal`, `DayChest`, `Scrapbook`, `Cosmetics`, `StartingPerks`). Glossary: Scrapbook and Unlock. `story.md` needed nothing more: ticket 04 added "Mum's journal". Roadmap 041 set to done.
  - **Hand play.** `.scratch/hand-play-backlog/issues/09-scrapbook-and-day-chest.md`: the scrapbook with a kid, and a look at the day chest in the running game (its Storage Crate stand-in model has never been seen in play).
  - Checks pass with `XDG_DATA_HOME=$(mktemp -d) SMOKE_FRAME_DELAY=40 tools/check.sh`.
