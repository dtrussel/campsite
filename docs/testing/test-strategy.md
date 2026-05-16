# Test Strategy

**Project:** Campsite Chronicles
**Version:** 0.1
**Date:** 2026-05-16

---

## Philosophy

For a Godot GDScript game at this stage, most testing is manual playtest + data validation. Automated testing should be used where it adds the most value without significant infrastructure cost.

Testing priorities (highest to lowest):
1. **Acceptance criteria** — each phase is done only when its criteria pass.
2. **Manual smoke tests** — can the game open and run without crashing?
3. **Data validation** — do resource definitions, building definitions, and recipes have valid data?
4. **Script-level unit tests** — for pure logic functions (XP calculations, cost checks, state transitions).

---

## A. Manual Playtest Checklists

A manual test checklist is created for each phase. The checklist is in the corresponding `.features/<feature>/test-plan.md` file.

### Phase 0 Checklist — Bootstrap Smoke Test

- [ ] Project opens in Godot 4 without import errors
- [ ] Main scene (`scenes/main/Main.tscn`) can be run with F5
- [ ] No script errors in the Output panel on startup
- [ ] Test world renders (even if flat/gray placeholder)
- [ ] Player placeholder is visible
- [ ] HUD renders (even if placeholder values)
- [ ] Campfire core placeholder is visible in the world
- [ ] All autoloads register without errors (check Output)
- [ ] No `null` reference errors in the first 5 seconds of running

### Phase 1 Checklist — Movement

- [ ] WASD moves the player in the correct directions
- [ ] Camera follows the player
- [ ] Player does not move through terrain edges (basic bounds)
- [ ] Campfire core is visible and positioned correctly
- [ ] HUD shows time-of-day counter incrementing
- [ ] No performance issues visible (frame rate reasonable)

### Phase 2 Checklist — Gathering

- [ ] Walking near a Wood node shows interaction prompt
- [ ] Pressing E gathers wood; node gives feedback (shrink, disappear, animation)
- [ ] Wood count in HUD increments by the correct amount
- [ ] Stone and Berries also gatherable and update HUD
- [ ] Cannot gather the same node twice without it respawning
- [ ] All 10 resource names visible in HUD (most at 0)

*(Add checklists per phase as each phase's feature folder is created.)*

---

## B. Smoke Test Scenes

Create minimal scenes that test a single system in isolation:

| File | Tests |
|------|-------|
| `game/tests/manual/test_resources.tscn` | ResourceManager add/remove/signal |
| `game/tests/manual/test_building_placement.tscn` | BuildManager placement validation |
| `game/tests/manual/test_companion_tasks.tscn` | Companion state machine transitions |
| `game/tests/manual/test_mob_wave.tscn` | Spawn, navigate, attack a static target |
| `game/tests/manual/test_xp_leveling.tscn` | ProgressionManager XP and level-up |

These scenes are not shipped in the game build; they are developer tools.

---

## C. Data Validation Checks

Run these checks whenever resource/building/mob data changes:

### Resource Definitions
- All 10 resource IDs are unique.
- Each resource has a non-empty `display_name`.
- Each resource has `max_stack > 0`.

### Building Definitions
- Each building ID is unique.
- Each building `scene` path resolves to a real `.tscn` file.
- Each building `max_health > 0`.
- Each building cost uses only valid resource IDs.

### Crafting Recipes
- Each recipe ingredient references only valid resource IDs.
- Each recipe produces a valid output (building or item).
- No recipe has zero XP reward if XP is expected.

### Mob Definitions
- Each mob ID is unique.
- `max_health > 0`, `move_speed > 0`, `attack_power >= 0`.
- `scene` path resolves.
- Loot table probabilities are in range [0.0, 1.0].

*Validation can be run via a simple GDScript tool script or manually by inspection during development.*

---

## D. Script-Level Tests

Place automated test scripts in `game/tests/automated/`. Use Godot's built-in testing patterns (no external framework required for the prototype).

### Example: XP Calculation Test
```gdscript
# game/tests/automated/test_progression_manager.gd
extends Node

func run_tests() -> void:
    _test_level_from_xp()
    _test_xp_to_next_level()

func _test_level_from_xp() -> void:
    # Level 1 at 0 XP
    assert(ProgressionManager.get_level_for_xp(0) == 1)
    # Level 2 at exactly threshold
    assert(ProgressionManager.get_level_for_xp(100) == 2)
    # Still level 2 just below level 3 threshold
    assert(ProgressionManager.get_level_for_xp(249) == 2)
    print("[PASS] test_level_from_xp")

func _test_xp_to_next_level() -> void:
    assert(ProgressionManager.get_xp_to_next_level_for(0) == 100)
    assert(ProgressionManager.get_xp_to_next_level_for(100) == 150)
    print("[PASS] test_xp_to_next_level")
```

### Example: ResourceManager Test
```gdscript
func _test_resource_add_remove() -> void:
    ResourceManager.add("wood", 10)
    assert(ResourceManager.get_amount("wood") == 10)
    assert(ResourceManager.remove("wood", 5) == true)
    assert(ResourceManager.get_amount("wood") == 5)
    assert(ResourceManager.remove("wood", 10) == false)  # insufficient
    assert(ResourceManager.get_amount("wood") == 5)      # unchanged
    print("[PASS] test_resource_add_remove")
```

---

## E. Acceptance Criteria Per Feature

Each feature folder in `.features/` contains a `test-plan.md` with:
1. **Setup:** What state must exist before testing.
2. **Steps:** Numbered steps to reproduce the test.
3. **Expected result:** What should happen.
4. **Pass criteria:** When to mark the feature as done.
5. **Failure notes:** Where to look if the test fails.

A feature is not marked **done** in `status.md` until all acceptance criteria in its `test-plan.md` pass.

---

## F. Performance Targets

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Frame rate (day phase, no mobs) | ≥60 FPS | Godot debug overlay (F1 in debug builds) |
| Frame rate (night, 10 mobs active) | ≥30 FPS | Debug overlay during night phase |
| Scene load time | < 3 seconds | Timed in editor |
| Save operation | < 1 second | Logged timestamp in SaveManager |
| Load operation | < 2 seconds | Logged timestamp on startup |

These are minimum targets for the prototype on a mid-range 2022 Windows PC. They do not need to be measured every session, but should be verified at the end of Phase 5 (first mobs active) and Phase 7 (full loop).
