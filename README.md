# Campsite (working title)

> A stylized 3D base-builder / survival defense game about Leo, a 7-year-old boy,
> protecting his family campsite from evil forest mobs that emerge at night.

## Pitch

By day you explore the woods, gather resources, craft tools, improve the
campsite, and assign tasks to family members and pets. At sunset, the forest
turns hostile: evil mobs swarm the camp and you must defend the campfire, the
tent, your family, and yourself. Survive the night, level up, and turn a
fragile camping trip into a magical woodland fortress.

## Status

**Prototype, ready for first playtest (v0.11.0-playtest1).** Hand-painted,
LoL-inspired 3D art: **Leo** (the big brother, played by you), his little
sister **Nela**, the Shadow Imps, trees, rocks, camp props and the painted
ground are modelled, painted and texture-baked by the scripts in
[`art/`](art/README.md).
The UI is icon-first for young players. See [`CREDITS.md`](CREDITS.md).
All sound (music, ambience and effects) is original and synthesized by
the scripts in [`art/audio/`](art/README.md#audio) (feature 016).

A complete 3-night run is playable:

1. Title screen.
2. Days of gathering, building, and crafting.
3. Nights of Shadow Imp waves.
4. A win or loss screen, and restart.

Roadmap phases 0–7 are implemented, plus the audio & feel pass
(feature 016). Next: repair and the unused resources (017), the Bramble
Beast (018), more buildings (019), and longer runs with save/load (020). See [`docs/roadmap/roadmap.md`](docs/roadmap/roadmap.md)
and [`.features/005-first-playtest-build/handoff.md`](.features/005-first-playtest-build/handoff.md).

**Playtesters:** follow [`docs/testing/playtest-001.md`](docs/testing/playtest-001.md).
The tester package is built with `tools/export_playtest.sh`.

## Technology stack

- **Engine:** Godot 4.3 (pinned in `tools/godot_version.txt`)
- **Language:** GDScript only (no C#)
- **Target platform:** Windows desktop first; other platforms later.
- **Licensing intent:** Free / open-source friendly.

The reasoning is captured in
[`docs/decisions/ADR-0001-engine-and-language-selection.md`](docs/decisions/ADR-0001-engine-and-language-selection.md).

## How to open the project

1. Install Godot 4.x (standard edition, **not** the .NET/Mono edition) from
   <https://godotengine.org/download>.
2. Launch Godot.
3. Click **Import**, navigate to this repository, and select
   `game/project.godot`.
4. Open the project.

## How to run the game

- Press **F5** in the Godot editor, or use **Project > Run**.
- The main scene is `game/scenes/ui/TitleScreen.tscn`; **Play** loads
  `game/scenes/main/Main.tscn`.

**Goal:** survive 3 nights and keep the campfire burning.

Controls (LoL-style; also shown in-game with **H**):

| Input | Action |
|-------|--------|
| Right click | Move / attack an imp / gather a resource / use the campfire |
| Left click | Attack or use what you click (never moves) |
| Mouse wheel | Zoom |
| Space | Attack the nearest imp |
| E | Gather the nearest resource |
| Q | Plant a crafted torch |
| R | Eat 2 berries to heal |
| C | Crafting panel (near the campfire) |
| B, then 1 / 2 | Build: Wooden Fence / Watch Post (R rotate, LMB place, RMB/Esc cancel) |
| F / G / T / Y | Sibling: follow / guard camp / gather / idle |
| N | Call the night early (daytime) |
| W A S D | Walk directly (optional) |
| H / Esc | Help / Pause menu (with Music and Sounds volume) |

## Checks and builds

```
tools/check.sh            # headless: import, validate all data, full smoke run
tools/export_playtest.sh  # Windows zip + self-tested Linux export in build/
tools/fetch_assets.sh     # re-vendor the CC0 models and fonts (only when the list changes)
tools/build_audio.sh      # rebuild the procedural sound into game/assets/audio/
```

Both scripts use `godot` on PATH, or `$GODOT`. Exports need the Godot
4.3 export templates.

## Repository structure

```
/game/                Godot project root (open game/project.godot in Godot)
  project.godot
  scenes/             Scenes grouped by domain
    main/             Main entry scene
    player/           Player character scenes
    companions/       Companion characters
    mobs/             Hostile creatures
    base/             Base / campsite core objects
    buildings/        Buildable structures
    resources/        Resource node scenes (trees, rocks, ...)
    ui/               HUD, menus, overlays
    world/            World / map scenes
  scripts/            GDScript by responsibility
    core/             Autoloads, managers, top-level services
    game_loop/        Day/night cycle, wave logic
    player/           Player controller and state machine
    companions/       Companion controller and tasks
    mobs/             Mob behavior
    base/             Campfire core, base health
    buildings/        Generic building behavior
    resources/        Resource gathering logic
    crafting/         Recipes and crafting flow
    progression/      XP and level-up rules
    ui/               UI controllers
    save/             Save/load services
    utilities/        Math, helpers, reusable bits
  assets/             Art, audio, materials, fonts
    placeholder/      Throwaway placeholder content
    custom/           Original models + painted textures (built from art/)
    kaykit/           Vendored CC0 KayKit packs (rigs, animations, backdrop)
    audio/            Sound effects, music and ambience (built from art/audio/)
    materials/        Shared materials
    fonts/            Fonts
  resources/          Godot .tres data resources (data-driven content)
    game_data/        Global tuning resources
    buildings/        Building definitions
    items/            Item / resource definitions
    mobs/             Mob definitions
    companions/       Companion definitions
  tests/
    manual/           (placeholder for manual smoke scenes)
    automated/        Headless smoke test (smoke_run.tscn)
    sim/              Balance simulation and screenshot capture
  tools/              In-project tools (validate_project.tscn)

/docs/                Project documentation
  requirements/       Product and functional requirements
  architecture/       Software architecture and coding standards
  design/             Game design specification
  roadmap/            Phased roadmap
  decisions/          Architecture decision records (ADRs)
  testing/            Test strategy and checklists

/tools/               check.sh, export_playtest.sh, pinned Godot version

/.features/           Agent feature workflow
  README.md
  000-project-bootstrap/
    plan.md
    status.md
    decisions.md
    test-plan.md
    handoff.md
```

## Documentation index

Start here if you are a new contributor or coding agent:

1. [Requirements specification](docs/requirements/requirements.md)
2. [Game design specification](docs/design/game-design-spec.md)
3. [Software architecture](docs/architecture/software-architecture.md)
4. [Coding standards](docs/architecture/coding-standards.md)
5. [Roadmap](docs/roadmap/roadmap.md)
6. [Test strategy](docs/testing/test-strategy.md)
7. [ADR-0001: Engine & language selection](docs/decisions/ADR-0001-engine-and-language-selection.md)
8. [Agent feature workflow](.features/README.md)
9. [Latest feature handoff](.features/016-audio-and-feel/handoff.md)
10. [Playtest 001 script](docs/testing/playtest-001.md)

## Development workflow

- Larger pieces of work are tracked in `.features/<id>-<slug>/` folders.
  Each folder contains a `plan.md`, `status.md`, `decisions.md`,
  `test-plan.md`, and `handoff.md`. See
  [`.features/README.md`](.features/README.md) for the rules.
- Small fixes and tweaks can be made directly without a feature folder, but
  documentation and tests should still be kept in sync.
- All architectural decisions go into `docs/decisions/` as ADRs.
- Coding style is documented in
  [`docs/architecture/coding-standards.md`](docs/architecture/coding-standards.md).

## Roadmap (summary)

| Phase | Goal                                       | Status |
|-------|--------------------------------------------|--------|
| 0     | Project foundation                         | done |
| 1     | Playable movement and camp scene           | done |
| 2     | Resources and gathering                    | done |
| 3     | Building placement                         | done |
| 4     | Companion prototype                        | done |
| 5     | Day/night cycle and first mob wave         | done |
| 6     | Combat, XP, and leveling                   | done |
| 7     | Crafting and first survival loop           | done |
| P1    | First human playtest                       | **next** |
| 8     | Save/load prototype                        | planned |

Full detail in [`docs/roadmap/roadmap.md`](docs/roadmap/roadmap.md).

## License

To be decided. The project intends to remain free / open-source friendly.
No copyrighted third-party assets are used.
