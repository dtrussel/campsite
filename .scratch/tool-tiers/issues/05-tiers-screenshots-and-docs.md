# 05: Screenshots and docs

Status: done
Blocked by: 03, 04

**What to build:** the feature's wrap-up: screenshots of the crafting panel with tier 3 available and of the HUD tier pip, the game design spec's crafting section updated, and tool tiers (040) set to done in the roadmap.

- [x] Screenshots: the crafting panel with tier 3 available, and the HUD tier pip.
- [x] `docs/` updated, and a hand-play check for whether the shard trade-off feels fair added to `.scratch/hand-play-backlog/`.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, implemented:** done.
  - **Screenshots.** Rendered for real under `xvfb-run` (OpenGL, 1280&times;720). `screenshots.gd` now shoots `04e2_tier_3_available` (after `04e_table_recipes`: Leo raised to tier 2, the Blaze Stick on offer at the table) and `04e3_tier_pips` (tier 3, the attack slot's three pips; the tier is set directly, because crafting it gives XP and the level-up picker would cover the HUD). Copied to `docs/design/screenshots/tool-tiers-crafting.png` and, cropped to the bottom HUD bar at 2&times;, `tool-tiers-hud-pips.png`.
  - **Docs.** Game design spec: the recipe table, resource uses, the hero-select note and a new "Tool tiers (feature 040)" section with both screenshots. Architecture: Hero's tool-tier API and the save's `"tier"`. Glossary: "Tool tier". Roadmap 040 set to done. No art changed (the tiers reuse the stick and slingshot icons), so `art/README.md` is unchanged.
  - **Hand-play:** `.scratch/hand-play-backlog/issues/07-tool-tiers-shard-trade-off.md`.
  - **Noticed:** owned tiers stay listed in the crafting panel with a disabled button, but the disabled style is faint, so in the screenshot the Sturdy and Ember Sticks look as craftable as the Blaze Stick. Left as is; it is a question on the hand-play ticket. The screenshot run also prints two "Trying to cast a freed object" errors at the scene swaps later on (story pages, Mum's arrival), unrelated to this ticket.
