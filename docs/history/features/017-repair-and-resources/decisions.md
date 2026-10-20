# Feature 017: Decisions

## Repair

- **Wood per tap.** Repair costs 1 Wood and restores 12 HP on a building,
  20 on the campfire. A fence (50 HP, 2 Wood + 1 Fiber) costs about 4
  Wood to fix from zero. That is cheaper than rebuilding in materials,
  but it takes time. Kids can understand "hammer = wood".
- **The campfire is fed, not hammered.** A right-click on the campfire
  already opens crafting, so the heal is the Feed the Fire recipe (and
  Nela's task). Thematically it is "put a log on". The recipe is
  disabled at full HP, so wood is never wasted.
- **The Repair group.** Structures join the `repairable` group and
  expose `get_max_hp()`, `get_missing_hp()`, `repair()` and
  `repair_per_tap`. The rules live in one static helper (`Repair`), used
  by Leo, Nela and the tests.
- **Nela's Repair task falls back to guarding.** She guards when there is
  nothing to fix or no wood left, and she fights imps in reach first.
  This keeps her useful at night instead of standing idle.

## Resources and loot

- **Glow Shards drop on every 3rd kill instead of by chance.** Young
  players get predictable rewards, and tests are deterministic. A full
  3-night run gives about 7–8 shards.
- **Where the new spots are.** The resource spots sit on the diagonals,
  at radius 13–15, between the spawn lanes. They are a trip, but they
  are not on the imps' path.
- **Berry Snack uses Mushrooms instead of Leaves** (as the spec had), so
  that mushrooms have a use.
- **Stone Hearth is an effect recipe.** It is not an item or a building.
  `CraftingRecipe` gained `effect` and `icon_name` (validated). The
  "once per run" rule comes from the campfire's own `has_hearth` flag,
  because the scene reloads each run.

## Buildings

- **The Simple Trap became the Snap Trap building** and was pulled
  forward from 019. It is the natural use for Scrap.
  - Traps have no collision layer. Imps walk onto them, and neither
    paths nor imps treat them as walls.
  - Trap "HP" is its snap count, so the HP bar shows the charges left.
  - Trap kills count as Leo's (XP).
- **The Glow Lantern reuses `torch.gd`** as an "Aura" child, with
  `burns_out_at_dawn = false`. That way imps' existing torch-slow logic
  covers it for free. An aura inside a build ghost stays inert.
- **Range ring in the build preview.** Meshes tagged with the
  `build_ghost_keep` meta keep their own material in the build ghost.
  The lantern's range ring is one, so it shows the range while placing.

## Art

- New props are built in `art/props/forage.py`, reusing camp.py's shape
  kit, and decimated to the 1.4k-triangle prop budget.
- The Glow Shard and the lantern crystal use a flat emissive material,
  not the painted bake.

## Tests

- **The smoke test waits on game time.** `_wait` now divides by the
  test's `SPEED`, not by `Engine.time_scale`. A hit-stop lowered the
  time scale mid-test and made one wait about 12 times longer than
  intended.
