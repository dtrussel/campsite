# 06: The companion picks its own card

Status: done
Blocked by: 01

**What to build:** when the companion (the sibling the player isn't controlling) levels up, it takes a random card from its own pool by itself. No picker opens, so combat is never interrupted for it. A small toast names the hero and the card, for example "Nela took Eagle Eye!". This was the spec's open question, decided 2026-10-20: the companion picks by itself.

- [x] Smoke: a companion level-up adds a perk to the companion without opening the picker, and shows the toast.
- [x] The companion's card follows the same pool rules: no repeats unless it stacks, and only its own hero's cards.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- 2026-10-20: Done. `PerkManager._on_level_up` now sends a companion
  level-up to `PerkManager.companion_pick(character)`: one card from
  `offer(character, 1)`, taken through `take()`, so it follows the same
  pool rules. It never runs while `is_restoring`. The HUD gained a
  reusable toast, `HudToast` (`scripts/ui/hud_toast.gd`), shown with
  `hud.show_toast(text, icon, color, seconds)`. Toasts stack down the
  right edge under the resource tray (up to three), use real-time
  timing and sit under the perk picker. Smoke: `_run_perk_06_scenario`.
