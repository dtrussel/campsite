# Feature 003 — Test plan

Run inside the Godot editor with **F5** on `Main.tscn`.

## Acceptance criteria (maps to roadmap Phase 4 + Phase 5)

### Day / night
- [ ] HUD time label shows `Day 1 - Day` and a countdown that ticks
      down each second.
- [ ] After the day duration, the label switches to `Sunset` (red)
      with a short warning countdown.
- [ ] After sunset, the label shows `Night`; the scene visibly darkens.
- [ ] After night, the label shows `Dawn` briefly, then `Day` for
      day 2 (`Day 2 - Day`).

### Base core
- [ ] HUD `Base HP` shows the campfire's actual HP (default 200).
- [ ] When a mob hits the campfire, HP visibly drops.
- [ ] If HP reaches 0, the HUD shows "Camp destroyed" and no new
      waves spawn.

### Mob wave
- [ ] On `night_started`, Shadow Imps start spawning from the four
      map edges.
- [ ] Each imp walks toward the campfire.
- [ ] If the path is blocked by a fence, the imp attacks the fence
      until it is destroyed, then continues.
- [ ] An imp at zero HP disappears (queue_free).
- [ ] When all imps are dead OR night ends, the wave ends; no more
      spawning until the next night.

### Companion
- [ ] A Sibling companion is visible near the campfire at game start
      (day 1, before any mobs spawn).
- [ ] The companion's task tag above its head reads `Idle` at start.
- [ ] Press **F** — the companion follows the player; tag reads
      `Follow Player`.
- [ ] Press **G** — the companion returns to the campfire and stands
      guard; tag reads `Guard Base`.
- [ ] Press **T** — the companion walks to the nearest gatherable
      resource node and gathers; the matching resource counter ticks
      up in the HUD. When the node is depleted, the companion picks
      the next nearest. Tag reads `Gather`.
- [ ] Press **Y** — the companion stops in place; tag reads `Idle`.
- [ ] Task hotkeys work during both day and night.

### Combat
- [ ] **LMB** outside build mode attacks the nearest mob within
      range; the mob loses HP.
- [ ] **LMB** in build mode places a building (does NOT trigger
      attack).
- [ ] A guarding companion attacks mobs that approach the campfire;
      mobs lose HP.
- [ ] The wave is winnable on night 1 with two fences and a guarding
      companion.

## Smoke checklist (no regressions)

- [ ] Project opens; no Output errors on startup.
- [ ] Main scene runs.
- [ ] WASD still moves; camera still follows.
- [ ] E still gathers from trees, rocks, and berry bushes.
- [ ] B still toggles build mode; LMB still places; resources still
      decrement.
- [ ] Esc quits when out of build mode; cancels build mode when in it.

## Edge cases worth exercising

- [ ] Press **T** in build mode — task is still assigned; build mode
      is unaffected.
- [ ] Press **B** while the companion is gathering — companion keeps
      working; build mode opens cleanly.
- [ ] Place a fence directly between a spawn point and the campfire —
      the wave preferentially destroys it before continuing.
- [ ] Spend most of the day gathering, then assign Guard at sunset —
      the companion repositions to the campfire before mobs arrive.
- [ ] Skip a day — let the wave run with no fences and no guarding
      companion. The campfire should take damage steadily.
- [ ] Place a fence next to the campfire, watch a mob attack the
      fence; once destroyed, the mob retargets the campfire.
