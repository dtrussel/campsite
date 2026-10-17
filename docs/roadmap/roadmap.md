# Roadmap

> Phase-based plan from empty repository to a complete first vertical
> slice. Each phase is independently shippable: the project should build
> and run at the end of every phase.
>
> **Status (2026-09):** Phases 0&ndash;7 done, plus an art &amp; feel pass
> (feature 006: stylized KayKit art, VFX, LoL-style UI and controls).
> Art passes 007&ndash;015 (hand-painted Leo, Nela, imps and props) and
> the audio &amp; feel pass (feature 016: procedural music, ambience and
> sound effects, hit-stop, sunset cue) are done. Playtest 1 can run on
> any of these builds. See "Next features" at the end for what follows.

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

## Playtest 1 &mdash; First human playtest (inserted before Phase 8)

**Goal:** confirm that a first-time player understands the loop and
enjoys it before we invest in save/load. Implemented by
`.features/005-first-playtest-build`.

**Deliverables**

- Title, pause, help, and end screens; 3-night win condition; restart.
- Threat to the boy and companion; feedback juice; balance pass.
- Windows playtest package, guided script, questionnaire, and event
  log (`docs/testing/playtest-001.md`).

**Acceptance criteria**

- A tester with no Godot install can launch the build and finish a
  run.
- `tools/check.sh` passes; the exported build passes `--selftest`.
- Feedback from at least 2 testers is triaged into the next feature.

## Phase 8 &mdash; Save/load prototype

*Done in feature 020 as an autosave at dawn plus Continue, with a
versioned `user://save.json`. No manual save or load menu.*

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

## Next features (agreed 2026-09)

Chosen after the feature 016 review. They are gameplay-first, with an
art track in parallel.

| Feature | Goal |
|---------|------|
| 016 Audio &amp; feel | **Done.** Procedural sound for everything, music and ambience moods, hit-stop, sunset cue, volume settings. |
| 017 Repair and resources | **Done.** Repair by Leo (hammer) and Nela (task V), and Feed the Fire. Clay pits, mushroom patches and junk piles; Glow Shards from imps. Berry Snack and Stone Hearth recipes; Snap Trap and Glow Lantern buildings. |
| 018 Bramble Beast | **Done.** A slow, tanky siege mob that walks to the nearest building (×3 damage). Waves mix 0/1/2 beasts into nights 1/2/3. |
| 019 Buildings | **Done.** Reinforced Wall; stash caps plus the Storage Crate; the Crafting Table with the Sturdy Stick, Slingshot, Bandage and Trap Refill. |
| 020 Longer runs + save/load | **Done.** 3- or 7-night runs; autosave at dawn with Continue (Phase 8, as autosave). Endless mode was not chosen. |
| 021 Mushroom Gremlin | **Done.** A fast thief: it steals up to 4 of the most plentiful resource from the stash (a crate, else the campfire) and runs. Caught, it drops the loot. Nights 2+ bring 1 or more. |
| 022 Imp remodel | **Done.** The Shadow Imp is sculpted and painted in the kids' style: forms, claws, a head tuft, slit eyes and rune markings, with a high-to-low bake at 8.4k triangles. |
| 023 Animation layering | **Done.** An AnimationTree per character: a walk/run blend, upper-body actions while moving, and a lean into turns. |
| 024 Living world | **Done.** Trees and bushes sway in the wind, leaves and pollen drift by day, fireflies come out at night, and running feet kick up dust. |
| 025 Painted props | **Done.** Painted jack-o'-lanterns, pumpkins, camp lanterns, water bucket, dead trees, hills and mountains replace the last KayKit props. Only the rigs and animations (and the axe icon) still come from KayKit. |
| 026 Bramble Beast remodel | **Done.** Rebuilt after the team's concept art: a sculpted, painted tree golem (carved angry face, moss mantle, log fists, twig antlers, leaf crown, berries, vines). Its own clips: breathing idle, stomping walk, two-fist slam, flinch, rising spawn, kneeling death, chest-thump roar. The slam is telegraphed: damage lands at impact (0.55 s), kids can step away, and the impact kicks up dust with a thud and a small shake. |
| 027 Mushroom Gremlin remodel | **Done.** Rebuilt after the team's concept: a cheeky mushroom goblin with a face under the cap (amber eyes, sly pupils, hooked nose, lopsided grin and fang), long pointed ears, clawed hands and feet, and a leaf-pouch satchel. Its own clips: shifty idle, tiptoe sneak, grab, satchel-clutching scurry (swapped in while it flees), flinch, pop-up spawn, plop death. |
| 028 Shadow Imp remodel | **Done.** Rebuilt after the team's concept: big head with oversized glowing eyes and slit pupils, cheeky fanged grin, pink bat ears, curled horns, spiky crest, small bat wings, S-curling arrow tail, lavender belly and magenta stripes. Its own clips: bouncy crouch idle, hop-run, claw swipe, flinch, rise from the ground, tumble-over death. All mobs now have original models and clips. |
| 029 Key-art splash | **Done.** The team's painted key art is the boot splash (with the gold logo) and a loading screen with kid-friendly tips while the camp loads on a background thread (no more freeze after Play). |
| 030 More loading art | **Done.** Three more team paintings (imp, beast, gremlin) join the loading screen, each with matching tips; a load never repeats the previous picture. |
| 031 Concept look pass | **Done.** Built after the team's October concept art, with a style guide (`docs/design/art-direction.md`).<br>- Golden-hour and teal-night lighting.<br>- A tilt-shift and warm-grade post pass (with a Blur switch).<br>- A flatter camera.<br>- An ochre clearing with a dirt path.<br>- Wildflower drifts, green pines and warm rocks.<br>- Cozy camp decor: seats, cooking tripod, signpost, lantern posts, market stall, stone well, and a cream A-frame tent.<br>- An HD-2D style finish: deeper warm shadows, painted surface detail, ink lines on props, a softer bokeh tilt-shift and a filmic warm grade.<br>- A model detail pass: 60 models rebuilt dense and baked (bark, planks, tiles, stitching, leaf tufts), plus fanned grass and cupped daisies. |
| 034 Choose your hero | **Done.** A hero select screen after Play: play Leo (melee stick-fighter) or Nela (ranged slinger); the other hero is the AI companion. Signature crafts follow the hero. Later: a companion picker step once there are more heroes. |
| 035 Story frame | **Done.** The story of [`story.md`](../design/story.md): an intro storybook after hero select (once per chapter), a voiced story card at each dawn and at the first shard, chapter endings before the win stats (3 Nights = Chapter 1 "The Dark Moon", 7 Nights = Chapter 2 "Into the Hollow"), and the defeat reason as a story line on the end screen. Placeholder paintings and no recordings yet. |
| 036 Moon Lantern | **Done.** A lantern by the tent. Press E next to it to hand over Glow Shards; each stage (3 in Chapter 1, 6 in Chapter 2) widens a safe light ring (4 to 9 m) that slows mobs and hurts imps, and a bright lantern turns gremlins back. Shard drops are a per-mob chance with pity. A HUD moon dial shows the stage. The model is a stand-in. |
| 043 Mum | **Done.** From the team's character sheet: six storybook expressions (a line picks one) and a 3D Mum on the kids' rig with a hand-keyed wave. In the true ending (Chapter 2) she walks out of the woods to the kids before the ending book, and afterwards she sits by the title fire. |
| 037 Sibling barks | **Planned, ready to build.** Speech bubbles over the kids on events (low HP, thief, beast, level up, sunset, dawn, lantern, knocked out), keyed by who is played, with cooldowns. The companion also warns "Behind you!". Voice by line id with a chirp until the recordings arrive. |
| 038 The Moon-Eater | **Planned.** The final-night boss of Chapter 2: telegraphed attacks, summons and a boss bar. Beating it is the true ending. |
| 039 Perk cards | **Planned.** On level-up, pick 1 of 3 cards (shared and hero-only) instead of only a flat stat bump. |
| 040 Tool tiers | **Planned.** The signature crafts get tiers (Stick &rarr; Sturdy &rarr; Ember Stick, Slingshot &rarr; Double &rarr; Glow Sling). The upper tiers cost shards, which the lantern also needs. |
| 041 Ranger's Journal and Camp Badges | **Planned.** A profile that persists between runs: badges for milestones, mum's journal pages, a scrapbook screen, and unlocks (Chapter 2 / 7 Nights after Chapter 1, cosmetics, starting perks). |
| 042 Endless mode | **Planned, optional.** "How long can you last?", unlocked by the true ending, with a best-nights record. |

Features 035&ndash;042 come from the mechanics brainstorm of 2026-10 (story
and meta progression, adventure tone). Their plans are in `.features/035-*`
to `.features/042-*`. The order is story first (035&ndash;038), then
choices (039&ndash;040), then meta (041&ndash;042). Ideas that were not
chosen this time: fire fuel and burn-down, night omens, last stand and
revive, a trader, well blessings and signpost chores.
