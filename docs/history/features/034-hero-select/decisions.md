# Feature 034: Decisions

- **Heroes are data; roles are shells.** A `HeroDefinition` (`resources/heroes/*.tres`) holds the body, stats, combat style and signature. `PlayerBoy.tscn` (player) and `Sibling.tscn` (companion) stay as the two role shells in `TestWorld.tscn` and dress themselves in `_enter_tree`, before their Visual builds the model. No spawner, and the camera, groups and tests keep working.
- **A hero keeps its playstyle in either role** (agreed with the user). Nela played is a ranged slinger (more reach, less HP and damage). Leo as companion is a melee bodyguard.
- **Signature crafts follow the hero, not the role.** Each hero joins the group `hero_<id>`; the recipe finds its hero there. The upgrade is a generic `apply_signature()` (damage bonus and/or reach factor, per role).
- **Ranged attacks are pebbles** (`PebbleShot`): the hit lands on impact after a 0.2 s flight, like the Bramble Beast's telegraphed slam.
- **A separate screen after Play** (agreed with the user), so a companion picker can become its second step. Until then the companion is `HeroRoster.default_companion()`: the first other hero.
- **The save is still version 1.** `party` is optional, and the old `stick` / `slingshot` keys are still read, so saves from before this feature continue as Leo with Nela.
- **Stage dressing near the camera is hidden** on the select screen, so lantern posts and crates never stand in front of the heroes.
