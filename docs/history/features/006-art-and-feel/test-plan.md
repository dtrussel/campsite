# Feature 006 — Test plan

## Automated
- [x] `tools/check.sh`: import, validator (every scene and model loads)
      and the smoke test, which checks:
  - the navmesh bakes;
  - a right-click move arrives;
  - a gather command collects;
  - an attack command kills an imp with auto-attacks;
  - a full win run and a full loss run.
- [x] `tools/export_playtest.sh`: the exported build self-tests.
- [x] Visual review of screenshots under Xvfb
      (`tests/sim/screenshots.tscn`) for:
  - title, help, day HUD, crafting, build ghost, sunset, night wave,
    pause, and the end screen.

## Manual (Windows)
- [ ] The title screen's 3D backdrop animates smoothly; the menu is
      readable.
- [ ] **Right click:**
  - on the ground: walk there, with a green marker;
  - on a tree: walk over and chop;
  - on an imp: chase and auto-attack;
  - on the campfire: open crafting.
- [ ] Hovering an imp shows a red rim, a red cursor and the range ring.
      Resources show gold, and the campfire shows teal.
- [ ] The characters animate: run, chop, attack, hit, knocked out, and
      the sibling getting back up at dawn.
- [ ] Imps rise from the ground at night and collapse into smoke when
      killed.
- [ ] Lighting blends from day to sunset to night to dawn; the fire is
      the key light at night.
- [ ] The HUD updates: clock, campfire bar, imp count, tray counts,
      action-slot counts and cooldown, XP bar, level badges.
- [ ] Performance: steady frame rate during the night-3 wave (11 imps).
