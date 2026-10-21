# 03: The scrapbook's Badges tab

Status: done
Blocked by: 02

**What to build:** a Journal button on the title opens the scrapbook. Its Badges tab shows a grid of every badge: earned ones in colour, locked ones as silhouettes with how to earn them.

- [x] Smoke: the scrapbook opens from the title and lists every badge, with earned and locked states matching the profile.
- [x] Screenshot: the Badges tab.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, done:** built test-first; the smoke `scrapbook scenario` covers the first box.
  - `Scrapbook` (`scripts/ui/scrapbook.gd`, `scenes/ui/Scrapbook.tscn`) is an overlay the title adds over itself (Journal button next to Help and Quit, the trophy glyph); Close or Esc emits `closed` and the title frees it.
  - Tabs are a row of toggle buttons over one page area. **For ticket 04:** `add_tab("Journal", page)` adds the Journal tab; `show_tab()` / `current_tab()` switch and report it.
  - The Badges tab is a 5 &times; 3 grid in `Badges.definitions()` order, with an "N of 15 badges earned" count. Earned: cream canvas, icon in colour. Locked: dark slot, the icon as a flat brass silhouette (a small canvas_item shader). Both show the name and how to earn it.
  - Screenshot: `screenshots.gd` shoots `01a_scrapbook_badges` (six badges earned, its own profile file), rendered under `xvfb-run` with OpenGL at 1280&times;720 and copied to `docs/design/screenshots/journal-scrapbook-badges.png`.
  - Checks also pass with `SMOKE_FRAME_DELAY=40`; the new checks wait on no tweens or timers.
