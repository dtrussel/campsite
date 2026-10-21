# Feature 005 — Test plan

## Automated (run before every push)

```
tools/check.sh                 # import + validate_project + smoke_run
tools/export_playtest.sh       # exports, self-tests the Linux export, zips Windows
```

- [x] `validate_project`: every script, scene and resource loads; ids
      are unique; scene paths resolve; every cost or recipe input is a
      real item that something in the world produces.
- [x] `smoke_run`:
  - gather from a tree and a pine;
  - craft and plant a torch;
  - a fence takes damage;
  - a Watch Post hits an imp;
  - survive 3 nights (each ends early when cleared) → WON;
  - second run: inventory and XP reset, campfire destroyed → LOST.
- [x] The exported Linux build passes `--selftest` (it loads 11 items,
      2 buildings, 1 recipe and the main scene from the PCK).

## Manual (Windows machine, exported build)

### Launch and menus
- [ ] Unzip, double-click `Campsite.exe`; the title screen appears.
      Note whether SmartScreen appears.
- [ ] Play → the help overlay is shown and the game is paused behind
      it; "Let's go!" starts the day.
- [ ] H reopens help; Esc/P pauses; Resume, Restart, Quit to title
      and Quit all work.

### Day
- [ ] E gathers from:
  - a tree (Wood + Leaves);
  - a pine (Resin + Wood);
  - a bush (Berries + Fiber);
  - a rock (Stone).
  The progress bar and the pickup text show.
- [ ] B → a green or red ghost follows the mouse. R rotates it, 1 and
      2 switch building, LMB places and spends resources, RMB or Esc
      cancels.
- [ ] C away from the fire shows "Go to the campfire to craft". Near
      the fire it opens the panel; Craft Torch is enabled only when
      you can afford it.
- [ ] Q plants a torch (light and a ring on the ground); Q with no
      torch shows a hint.
- [ ] R with fewer than 2 berries shows a hint. When hurt, it heals
      15 HP.
- [ ] N skips to sunset; the banner warns you.

### Night
- [ ] The banner says "Night N - X Shadow Imps are coming!"; the HUD
      shows the imp count.
- [ ] Imps walk to the fire, chew through fences, and chase the boy
      when he is close.
- [ ] Hits show a flash and a number; the boy's HP bar drops.
- [ ] Imps near a torch are slowed and take damage.
- [ ] A Watch Post pelts imps in range.
- [ ] Killing every imp brings dawn early; the boy and Sibling get
      +10 XP.
- [ ] The Sibling knocked out → the label reads "Knocked out", and
      they get back up at dawn.

### End of run
- [ ] Surviving night 3 → Victory screen with stats.
- [ ] The campfire at 0, or the boy at 0 HP → Game over screen with
      the reason.
- [ ] Play again starts clean (resources 0, Lv 1, day 1).
- [ ] The log file exists at the path shown and contains the run's
      events.

### Performance
- [ ] Smooth on the tester's machine; note FPS drops at night 3
      (11 imps).
