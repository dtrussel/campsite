# Development Roadmap

**Project:** Campsite Chronicles
**Version:** 0.1
**Date:** 2026-05-16

Each phase is a self-contained vertical slice increment. A phase is **done** when all acceptance criteria pass.

---

## Phase 0: Project Foundation ← *Current*

**Goal:** Create a clean, documented repository foundation that any coding agent can pick up from.

**Deliverables:**
- [x] Repository directory structure
- [x] `.gitignore`, `.editorconfig`
- [x] `README.md`
- [x] ADR-0001: Engine and language selection
- [x] Requirements specification
- [x] Game design specification
- [x] Software architecture specification
- [x] Coding standards
- [x] Test strategy
- [x] Development roadmap (this file)
- [x] `.features/` workflow documentation
- [x] `.features/000-project-bootstrap/` plan, status, decisions, test-plan, handoff
- [ ] Minimal runnable Godot project skeleton (Main.tscn, HUD, placeholder player, campfire, test world)

**Acceptance Criteria:**
- [ ] Project opens in Godot 4 without errors
- [ ] Main scene runs (shows test world, player placeholder, HUD)
- [ ] All documentation files exist and are readable
- [ ] `.features/000-project-bootstrap/handoff.md` is complete
- [ ] Next coding agent can continue from the handoff file alone

---

## Phase 1: Playable Movement and Camp Scene

**Goal:** Player can move around a real test map with a campfire.

**Deliverables:**
- 3D test world (flat terrain, basic lighting)
- Player boy placeholder mesh + movement
- Isometric/top-down camera that follows the player
- Campfire Core placeholder in the world
- HUD placeholder (shows time-of-day, base HP, resource stubs)
- Day/night visual transition (environment change only, no gameplay yet)

**Acceptance Criteria:**
- Player can move in all four directions (WASD)
- Camera follows player with smooth lag
- Campfire core object is visible in the world
- HUD renders without errors
- Day/night visual difference is visible (lighting change)

---

## Phase 2: Resources and Gathering

**Goal:** Player can gather resources; HUD updates in real time.

**Deliverables:**
- 10 ResourceDefinition `.tres` files (all resource types)
- ResourceManager autoload with full inventory API
- At least 3 gatherable resource node types in the test world (Wood, Stone, Berries)
- Gathering interaction on resource nodes (approach + E key)
- Gathering animation / feedback (node disappears or shrinks)
- HUD resource display updated via `resource_changed` signal

**Acceptance Criteria:**
- Player can gather Wood, Stone, and Berries
- Resource counts increment in HUD after gathering
- All 10 resources are shown in HUD (most at 0 initially)
- ResourceManager correctly prevents going below 0

---

## Phase 3: Building Placement

**Goal:** Player can spend resources to place buildings.

**Deliverables:**
- BuildManager autoload
- BuildingDefinition `.tres` files for: Campfire Core, Wooden Fence, Watch Post
- Build mode toggle (B key)
- Placement ghost (node preview following mouse)
- Valid/invalid placement indicator (green/red)
- Resource cost deduction on confirm
- Wooden Fence placed as a physical object in the world

**Acceptance Criteria:**
- Player can enter build mode and select Wooden Fence
- Ghost preview follows mouse position
- Red ghost when over invalid terrain or overlap
- Green ghost on valid terrain
- Confirming placement deducts resources and places fence
- Insufficient resources → placement blocked with visual feedback

---

## Phase 4: Companion Prototype

**Goal:** At least one companion behaves autonomously and responds to task assignment.

**Deliverables:**
- Companion scene with placeholder mesh
- CompanionController with state machine
- Task: Follow Player (companion navigates near player)
- Task: Guard Base (companion patrols campfire perimeter)
- Simple task assignment UI (click companion → task panel appears)
- Companion task icon indicator above companion

**Acceptance Criteria:**
- Companion is visible in the world
- Clicking companion opens a task selection panel
- Assigning "Follow Player" → companion moves to stay near player
- Assigning "Guard Base" → companion navigates to campfire and patrols
- Companion task icon updates in HUD

---

## Phase 5: Day/Night Cycle and First Mob Wave

**Goal:** Night begins automatically; Shadow Imps attack; the game can survive to morning.

**Deliverables:**
- TimeManager autoload with real-time day/night timer
- Environment/lighting transitions per phase (day, sunset, night, dawn)
- Sunset warning signal → HUD warning panel appears
- WaveManager: spawns Shadow Imps at night
- ShadowImp mob scene with direct movement toward campfire/fence
- Basic mob attack behavior (damages buildings on contact/timer)
- Base damage reflected in HUD base health bar
- Wave ends at dawn (all mobs despawn or die)
- Day counter increments

**Acceptance Criteria:**
- Night begins automatically after day duration
- HUD shows sunset warning with countdown
- Shadow Imps spawn at map edges and move toward campfire
- Imps attack campfire/fence and reduce HP
- HUD base health bar decreases
- Dawn arrives after night duration; imps despawn
- Day counter in HUD increments

---

## Phase 6: Combat, XP, and Leveling

**Goal:** Player and companions can defeat mobs; XP awards level-up.

**Deliverables:**
- Player attack action (click or key near mob)
- Mob health bar / damage response
- Mob death (animation + despawn)
- XP award to player on mob death
- ProgressionManager tracking XP per character
- Level-up event with visual feedback
- Companion (Guard task) attacks nearby mobs
- Companion gains XP from combat

**Acceptance Criteria:**
- Player can attack Shadow Imps
- Imps take damage and die at 0 HP
- Player receives 10 XP per imp killed
- Player levels up at 100 XP with visual/audio feedback
- A guarding companion also attacks imps in range and gains XP
- Character level shown in HUD or character panel

---

## Phase 7: Crafting and First Survival Loop

**Goal:** Crafting is functional; the full day-night loop is survivable.

**Deliverables:**
- CraftingRecipe `.tres` file for Wooden Fence (3 Wood + 2 Fiber)
- Simple crafting menu (key press opens recipe list)
- Recipe availability check (shows grayed if insufficient resources)
- Crafting confirms → resources deducted → output produced → XP awarded
- Balance pass: gather rates, building HP, mob damage, XP thresholds
- Full loop: wake up → gather → build → night → survive → dawn → repeat

**Acceptance Criteria:**
- Player can open crafting menu
- Wooden Fence recipe visible; grayed if cannot afford
- Crafting consumes resources and produces building placement
- Crafting grants XP
- The full day/night loop can be run 2–3 times without crashes

---

## Phase 8: Save/Load Prototype

**Goal:** Player can save and reload game state.

**Deliverables:**
- SaveManager autoload
- Save data: resource inventory, day count, base health, placed buildings, character levels
- Save triggered by F5 or menu
- Load on startup if save exists
- Save file stored in user:// directory
- Save data versioned (save_version key)

**Acceptance Criteria:**
- Player can save game
- Closing and reopening prompts to load
- Loaded game restores: resource counts, day number, base health, placed fence/buildings, character levels
- Old save files from a different version show a warning rather than crashing

---

## Future Phases (Backlog)

| Phase | Topic |
|-------|-------|
| 9 | Additional mob types (Bramble Beast, Night Crow) |
| 10 | Sibling and Dog companion implementations |
| 11 | More building types (Storage Crate, Crafting Table) |
| 12 | More crafting recipes (Torch, Berry Snack, Trap) |
| 13 | Scout task for companions |
| 14 | Repair task for companions |
| 15 | Gather task for companions |
| 16 | Environmental storytelling and handcrafted map |
| 17 | Escalating difficulty waves (larger, stronger waves per day) |
| 18 | Art pass (real stylized 3D assets) |
| 19 | Audio implementation |
| 20 | Polish, playtesting, and balance |
| TBD | Procedural world elements |
| TBD | Expanded progression and ability unlocks |
| TBD | macOS/Linux/Web export |

---

## Milestone Summary

| Milestone | Phases | Description |
|-----------|--------|-------------|
| **Proof of Concept** | 0–1 | Project opens; player can move |
| **Core Mechanics** | 2–5 | Gather, build, companion, night attack |
| **First Vertical Slice** | 6–7 | Fully survivable loop with XP and crafting |
| **Stable Prototype** | 8 | Save/load; shareable for playtesting |
| **Alpha** | 9–17 | More content, companions, mobs, buildings |
| **Beta** | 18–20 | Art, audio, polish, balance |
