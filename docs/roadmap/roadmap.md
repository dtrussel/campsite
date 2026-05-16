# Roadmap

> Phase-based plan from empty repository to a complete first vertical
> slice. Each phase is independently shippable: the project should build
> and run at the end of every phase.

## Phase 0 &mdash; Project foundation

**Goal:** create a clean Godot 4 / GDScript repository foundation.

**Deliverables**

- Repository layout (folders for `game/`, `docs/`, `tools/`,
  `.features/`).
- README.
- Engine / language ADR.
- Requirements specification.
- Game design specification.
- Software architecture specification.
- Coding standards.
- Feature workflow (`.features/README.md`).
- Minimal runnable Godot project skeleton.

**Acceptance criteria**

- Project opens in Godot 4.
- Main scene runs.
- All documents listed above exist and are coherent.
- Next coding agent can continue from
  `.features/000-project-bootstrap/handoff.md`.

## Phase 1 &mdash; Playable movement and camp scene

**Goal:** the boy walks around a small map with a campfire core and a
placeholder HUD.

**Deliverables**

- Test world with ground plane and a few visual cues (rocks, trees as
  placeholders).
- Player boy placeholder character.
- Top-down / isometric camera that follows the player.
- Basic WASD movement.
- Campfire core placeholder at the center of the map.
- HUD placeholder showing time of day, base health, and all 10 resources.

**Acceptance criteria**

- Player can move around the test map.
- Camera follows the player smoothly without snapping.
- Campfire core is visible and clearly central.
- HUD displays placeholder time, base HP, and 10 resource counters.

## Phase 2 &mdash; Resources and gathering

**Goal:** the player gathers resources and the UI reflects it.

**Deliverables**

- `ResourceDefinition` data class.
- `.tres` instances for all 10 resources.
- `ResourceManager` autoload (inventory, signals).
- Three gatherable resource node scenes (tree, rock, berry bush).
- Gather interaction (E key, gather timer, success animation/SFX hook).
- Resource UI rows update when inventory changes.

**Acceptance criteria**

- Player can gather Wood, Stone, and Berries from world nodes.
- Resource counts update in the HUD via signals.
- All 10 resources are visible in the HUD even if only 3 are gatherable.

## Phase 3 &mdash; Building placement

**Goal:** the player builds simple structures.

**Deliverables**

- `BuildingDefinition` data class and `.tres` files for prototype set.
- `BuildManager` autoload with build mode toggle.
- Placement ghost with green / red feedback.
- Placement validation (no overlap, on ground, resources sufficient).
- Wooden Fence and Watch Post scenes.
- Resource cost spend on placement.

**Acceptance criteria**

- Player can enter build mode, select Wooden Fence, place it on valid
  terrain.
- Invalid placement is rejected with red ghost feedback.
- Placed building appears in world and persists.
- Resource counts decrease by the recipe cost.

## Phase 4 &mdash; Companion prototype

**Goal:** at least one companion follows or guards.

**Deliverables**

- Companion scene and controller.
- Task state machine (Idle / Follow / Guard).
- Selection (click) and task assignment (hotkey or HUD button).
- Companion XP counter (placeholder, not yet rewarding gameplay).
- Visible task indicator (text or icon above companion).

**Acceptance criteria**

- Companion can be set to Follow Player and walks behind the boy.
- Companion can be set to Guard Base and remains near the campfire.
- Current task is visible to the player.

## Phase 5 &mdash; Day/night cycle and first mob wave

**Goal:** the world has a clock, and at night Shadow Imps attack.

**Deliverables**

- `TimeManager` autoload with day / sunset / night / dawn states.
- Sunset warning signal and matching HUD cue.
- `MobDefinition` data class.
- `ShadowImp` scene and controller.
- `MobSpawner` and simple wave logic.
- Mob targets the base core or nearest fence.
- Building / base HP reduction on mob hit.

**Acceptance criteria**

- Day automatically transitions to night.
- Shadow Imps spawn from the map edge.
- Mobs path toward the campfire core / fences.
- Base health decreases when mobs attack.
- Day resumes after the wave timer expires or all mobs die.

## Phase 6 &mdash; Combat, XP, and leveling

**Goal:** mobs can be killed, characters gain XP and level up.

**Deliverables**

- Player attack (E or left-click).
- Companion attack when in Guard state and a mob is in range.
- Mob HP and death effect.
- `ProgressionManager` autoload with XP totals and level thresholds.
- XP awards on mob kill, on building, on gathering.
- Level-up signal and small stat bump.

**Acceptance criteria**

- Player can defeat Shadow Imps.
- XP is awarded and visible in HUD.
- A character can level up from zero in a single playtest session.
- Companion XP works for companions assigned to Guard during a successful
  defense.

## Phase 7 &mdash; Crafting and first survival loop

**Goal:** crafting closes the day-loop: gather &rarr; craft &rarr; defend.

**Deliverables**

- `CraftingRecipe` data class and one playable recipe (recommended:
  Torch).
- Crafting UI or station interaction.
- Recipe consumes resources, produces output, grants XP.
- Light balance pass on existing values.

**Acceptance criteria**

- Player can craft at least one item.
- Crafting visibly consumes resources and grants XP.
- The recipe&rsquo;s output is usable in the world.

## Phase 8 &mdash; Save/load prototype

**Goal:** the player can save and resume.

**Deliverables**

- `SaveManager` autoload with versioned schema.
- Save resource inventory, day number, time-of-day, base HP, placed
  buildings, and character levels / XP.
- Save / Load menu options.

**Acceptance criteria**

- Player can save mid-day and reload to the same state.
- Reloaded state restores the campfire, fences, watch posts, resource
  counts, day number, and character XP / level.
- Schema version is written; loader rejects mismatched versions cleanly.

## Beyond Phase 8

After Phase 8 the project has a complete vertical slice. Subsequent
planning is captured in new `.features/` folders as new goals are chosen:

- Additional mob types (Bramble Beast, Night Crow, Mushroom Gremlin).
- Additional companions (Parent, Cat).
- More buildings (Storage Crate, Crafting Table, Reinforced Wall).
- Skill trees or alternative progression structures.
- World expansion (multiple biomes, deeper forest).
- Polish pass on art, audio, UI, juice.
