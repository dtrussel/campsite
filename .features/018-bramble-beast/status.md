# Feature 018: Status

**Done** (pending a human playtest).

## 2026-09-29

- **Built:**
  - model and animations;
  - `BrambleBeast.tscn` and `bramble_beast.tres`;
  - the siege AI, damage multiplier and knockback scale;
  - mixed waves and the `mob_spawned` signal;
  - the HUD banner, two sounds and two bursts.
- **`tools/check.sh` passes.** The smoke test checks:
  - the wave make-up per night, with beasts in the second half;
  - that a beast walks past Leo 3 m away and hits a fence for 12;
  - that it barely flinches.
- **Screenshot:** the night view with a beast at the fence (Xvfb).
- **Balance sim:** see decisions.md.
