# 12: Head look-at

Status: done (open: the user's visual sign-off)
Blocked by: none (can start immediately)

**What to build:** each kid turns their head and chest toward what they're paying attention to. The order is:

1. the attack target while fighting;
2. the resource or building they're working on while gathering or building;
3. the nearest mob within about 6 m while idle at night;
4. otherwise, the other hero now and then.

The look is capped at about 60° of head and chest turn, eases in and out, and blends off during full-body actions. The player's hero and the companion follow the same rules.

- [x] A look-at `SkeletonModifier3D` on the character visual, and a way for gameplay to set or clear its focus.
- [x] Unit: the target-priority rule picks the right target in each case, and nothing when no case applies.
- [x] Smoke: for both roles, the head turns toward the attack target while fighting and toward the resource while gathering, within the cap.
- [x] In-game captures are under `## Comments` for sign-off.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-25, implemented:**
  - `HeadLook.pick` (`game/scripts/characters/head_look.gd`) is the target order: the attack target, then the work target, then the nearest mob within 6 m when idle at night, then the other hero while a glance is due (`HeadLook.Glance`: about 1.4 s every 5–11 s). Freed nodes are skipped.
  - `HeadLookModifier` (`game/scripts/utilities/head_look_modifier.gd`, a `SkeletonModifier3D`) turns the chest (40%) and head (60%) about the up axis on top of the clip. `CharacterVisual` adds it when `head_look` is on (HeroBody turns it on for the two heroes in the camp; hero select and the title backdrop build their own visuals and leave it off), eases toward the focus, caps it at 60° and blends it out during `hit`, `death`, `getup` and a standing `cheer`. Gameplay sets the focus with `set_look_focus(node)`; tests read `look_focus()` and `look_turn_degrees()`.
  - `Hero._process` picks the focus every frame in both roles. Role hooks `_fight_target` and `_work_target` add the player's attack command and the site being built or repaired (both roles).
  - Tests: `game/tests/unit/test_head_look.gd` (the order, out-of-range mobs, nothing when no case applies, freed targets) and the smoke script `hero_look_at.gd` (both kids in both roles: a mob 90° off turns the head to the cap, one 30° off about 30°, a tree off to the side turns it the other way). The smoke script is its own file, not `hero_animation.gd`, so it does not collide with ticket 02's new script; fold it in later if wanted.
  - Captures for sign-off, the look off (left) and on (right) while fighting a Bramble Beast to the side: `../captures/12-look-at-leo-off-vs-on.png` and `../captures/12-look-at-nela-off-vs-on.png`. The chest, pack and head turn toward the beast.
  - `tools/check.sh`: validate OK, unit PASSED, smoke PASSED (both passes), selftest OK.
- **2026-10-26, review fixes:** the smoke checks moved from `hero_look_at.gd` into `hero_animation.gd` (tolerances named, the cap read from `CharacterLook.MAX_DEGREES`). The look lives in `CharacterLook`, composed by `CharacterVisual`. Idle at night, the hero rescans the mobs every `look_mob_scan_seconds` (0.25 s), not every frame. Status set to `done (open: the user's visual sign-off)`.
