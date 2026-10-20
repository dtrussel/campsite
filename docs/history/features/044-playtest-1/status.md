# Feature 044: Status

**Done.** All eight points from the first user test are in.

- **Intro:** it plays after hero select on every new game. `story.cfg` still records which intros were seen, but no longer gates them.
- **Nela stuck:**
  - The companion follows nav paths in every task.
  - Smoke: told to guard from behind a 7 m wall, she walks round it (about 3 s, no hop needed).
  - The companion's `move_speed` from its definition was ignored before; that is fixed.
- **Resources:**
  - The tray shows 6 resources plus torch and snack, on 2 rows.
  - New costs:
    - Fence: 3 wood
    - Watch Post: 5 wood, 2 stone
    - Trap: 3 wood, 1 scrap
    - Torch: 2 wood
    - Snack: 3 berries
    - Bandage: 2 berries, 1 wood
    - Stick: 4 wood, 2 scrap
    - Slingshot: 3 wood, 2 scrap
- **Pacing:**
  - Day/sunset/night/dawn: 200/12/120/6 s.
  - Speeds: heroes 4.0, companions 3.9; imp 1.9, bramble 1.2, gremlin 2.5, Moon-Eater 0.75.
  - Cooldowns ×1.25. Wind-up 0.22 s, spawn interval 5.5 s, regen 1.2 HP/s.
  - `balance_sim` (task 2) is close to before:
    - fight: win with the boy on 13/65 at night 3 (before: 13/65);
    - idle: knocked out on night 2 (before: also night 2).
- **Auto-attack:** on by default, with the pause-menu "Auto-fight" switch. It chains to the next mob and resumes the gather it interrupted. Smoke stages its other fights with it off.
- **Camera:** 28° and +0.8 m lift at full zoom-in. The default view is unchanged.
- **Blur:** Soft by default; Off / Soft / Strong in the pause menu. An old `tilt_shift = false` setting reads as Off.
- **Construction:**
  - A placed building is a blueprint: sunk into a pale site, with a blue progress bar. The hero walks over and hammers it (chop clip, wood chips each swing), then it rises with dust and the place sound.
  - It takes 2–4 s of work per building. HP starts at 20% and grows with progress.
  - Saves keep the progress.
  - Screenshot `04b2_blueprint_building` shows a half-built fence with Leo hammering.
