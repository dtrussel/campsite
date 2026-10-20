# Feature 004 — Decisions

## D-004-1 — Kill credit via last-damager attribution

- **Decision:** `Mob.take_damage(amount, source)` records the most
  recent damager in `_last_damage_source`. On death, that source
  gets the full `xp_reward`. No assist credit, no shared XP.
- **Rationale:** Simplest model that matches what comparable games
  do for prototype levelling. Assist credit needs a damage-share
  policy and a window; out of scope here.

## D-004-2 — Per-character state owned by the autoload

- **Decision:** `ProgressionManager._state` is a dictionary keyed
  by character `Node`, value `{ level, xp, stats }`. Characters
  call `register_character(self, stats)` on `_ready` and the
  manager cleans them up on `tree_exiting`.
- **Rationale:** Putting state on the autoload keeps progression
  centralised so saving / loading touches one place. The
  character only consumes signals.

## D-004-3 — Only `attack_damage` is bumped on level up

- **Decision:** Level up emits `level_up(character, new_level)`.
  The player and the Sibling listen and increment their runtime
  `attack_damage` by `stats.attack_damage_per_level`. HP fields on
  the definition are unused for now (no enemy damages characters).
- **Rationale:** A visible stat bump is required for the feature
  to feel real; one stat is enough. HP wiring is deferred until
  characters can actually take damage.

## D-004-4 — Survive-night bonus

- **Decision:** `ProgressionManager` listens to
  `TimeManager.dawn_started` and awards a fixed 10 XP to every
  registered character.
- **Rationale:** Encourages defending into dawn rather than
  hiding; cheap to implement; tunable.

## D-004-5 — Gather XP is per-event, not per-unit

- **Decision:** Each `ResourceNode._on_gather_complete` awards 1
  XP to the actor regardless of `yield_amount`.
- **Rationale:** Per-unit would over-reward berry bushes (yield 3)
  versus rocks (yield 1) and invites grinding loops. The event
  itself is the work; the resource amount is the payoff.

## D-004-6 — Build XP credited to whoever is in the `player` group

- **Decision:** `BuildManager` finds the player via
  `get_tree().get_nodes_in_group("player")[0]` after a successful
  placement and awards 5 XP.
- **Rationale:** Build mode is player-driven; companions cannot
  enter build mode in this feature. When companion-driven building
  arrives, the action will already record an actor and the call
  becomes `award_xp(actor, 5, &"build")`.

## D-004-7 — HUD updates on signal, not poll

- **Decision:** The HUD subscribes to `xp_gained` and `level_up`
  and refreshes the matching row's text. On `level_up` the row
  briefly flashes green.
- **Rationale:** Matches the existing HUD pattern (signal-driven
  rows, no per-frame polling for inventory).

## D-004-8 — Sibling-stats `.tres` separate from companion-definition `.tres`

- **Decision:** `Sibling.tscn` carries two resources: the existing
  `CompanionDefinition` (`sibling.tres`) for base archetype values
  and a new `CharacterStatsDefinition` (`sibling_stats.tres`) for
  the progression curve.
- **Rationale:** Archetype data (display name, scene, role) and
  progression data (XP table, per-level bumps) have different
  audiences and different rates of change. Splitting them now
  costs one extra `.tres` and saves a confusing merge later.
