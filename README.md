# Campsite (working title)

> A stylized 3D base-builder / survival defense game about Leo (7) and his
> sister Nela, protecting their campsite from the forest's shadows at night
> while their mum is missing and the moon has gone dark.

## Pitch

By day you explore the woods, gather resources, craft tools, improve the
campsite, and give your sibling tasks. At sunset, the forest turns hostile:
lost, cold shadows swarm toward the light and you must defend the campfire,
the tent, each other, and the old Moon Lantern. Survive the nights, follow
Mum's notes, and bring the moon back.

## Status

**Prototype, ready for first playtest (v0.25.0-playtest1).** Hand-painted,
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
(feature 016) and repair with the full resource set (feature 017):
- clay pits, mushroom patches and junk piles;
- Glow Shards from imps;
- Feed the Fire, the Berry Snack and the Stone Hearth at the campfire;
- Snap Traps and Glow Lanterns in the build menu;
- hammer repairs by Leo and by Nela.

The **Bramble Beast** (feature 018) joins nights 2 and 3. It is slow
and tough, and tears down fences and posts before going for the fire.

Feature 019 adds:
- the **Reinforced Wall**;
- **stash limits** (20 of each resource), raised by **Storage Crates**;
- the **Crafting Table**, a second crafting spot with the Sturdy Stick,
  Nela's Slingshot, Bandages and Trap Refills.

Feature 021 adds the **Mushroom Gremlin**, a fast little thief. It
grabs a few of your most plentiful resource and runs back to the forest.
Catch it to get the loot back.

Feature 031 brings the look closer to the team's concept art.
- Golden-hour light and a miniature tilt-shift view.
- A flowery meadow with a dirt path.
- Cozy camp decor.
- Warm lantern light at night.

Feature 020 adds **3- or 7-night runs**. The game **autosaves every
morning**, and **Continue** on the title screen resumes the run. See [`docs/roadmap/roadmap.md`](docs/roadmap/roadmap.md)
and [`docs/history/features/005-first-playtest-build/handoff.md`](docs/history/features/005-first-playtest-build/handoff.md).

**Playtesters:** follow [`docs/testing/playtest-001.md`](docs/testing/playtest-001.md).
The tester package is built with `tools/export_playtest.sh`.

## Technology stack

- **Engine:** Godot 4.3 (pinned in `tools/godot_version.txt`)
- **Language:** GDScript only (no C#)
- **Target platform:** Windows desktop first; other platforms later.
- **Licensing intent:** Free / open-source friendly.

The reasoning is captured in
[`docs/adr/0001-engine-and-language-selection.md`](docs/adr/0001-engine-and-language-selection.md).

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

**Goal:** survive 3 (or 7) nights and keep the campfire burning. The
game saves itself every morning; use **Continue** on the title screen to
resume.

Controls (LoL-style; also shown in-game with **H**):

| Input | Action |
|-------|--------|
| Right click | Move / attack an imp / gather a resource / use the campfire / repair a damaged building |
| Left click | Attack or use what you click (never moves) |
| Mouse wheel | Zoom |
| Space | Attack the nearest imp |
| E | Gather the nearest resource |
| Q | Plant a crafted torch |
| R | Eat: a Berry Snack (+35 HP) if you have one, else 2 berries (+15 HP) |
| X | Put a bandage on Nela (next to her): +25 HP, or wakes her up |
| C | Crafting panel (near the campfire or a Crafting Table) |
| B, then 1–7 | Build: Fence / Reinforced Wall / Watch Post / Snap Trap / Glow Lantern / Storage Crate / Crafting Table (R rotate, LMB place, RMB/Esc cancel) |
| F / G / T / Y / V | Nela: follow / guard camp / gather / idle / repair |
| N | Call the night early (daytime) |
| W A S D | Walk directly (optional) |
| H / Esc | Help / Pause menu (with Music and Sounds volume) |

## Checks and builds

```
tools/check.sh            # headless: import, validate all data, full smoke run
tools/export_playtest.sh  # Windows + Linux zips in build/ (Linux build self-tested);
                          # --split also makes the Windows build as program + data zips
tools/fetch_assets.sh     # re-vendor the CC0 models and fonts (only when the list changes)
tools/build_audio.sh      # rebuild the procedural sound into game/assets/audio/
```

Both scripts use `godot` on PATH, or `$GODOT`. Exports need the Godot
4.3 export templates.

### Continuous integration

`.github/workflows/build.yml` runs on every push and pull request:
`tools/check.sh`, then `tools/export_playtest.sh`. The Windows and Linux
zips are attached to the run as the `Campsite-<version>` artifact (kept
14 days). CI caches Godot and the export templates it needs; it does not
rebuild the art (the baked assets are committed).

To publish a release, bump `config/version` in `game/project.godot`,
then push a matching tag, e.g. `git tag v0.25.0-playtest1 && git push
origin v0.25.0-playtest1`. The tag's run creates a GitHub Release with
both zips (a pre-release when the version has a `-suffix`).

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
    kaykit/           Vendored CC0 KayKit packs (rigs and animations)
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
    sim/              Balance simulation, screenshot and animation-frame capture
  tools/              In-project tools (validate_project.tscn)

/docs/                Project documentation
  requirements/       Product and functional requirements
  architecture/       Software architecture and coding standards
  design/             Game design specification
  roadmap/            Phased roadmap
  adr/                Architecture decision records (ADRs)
  agents/             How agent skills use this repo (issue tracker, labels, domain docs)
  history/features/   Archived feature folders 000-048 (read-only)
  testing/            Test strategy and checklists

/tools/               check.sh, export_playtest.sh, pinned Godot version

/.scratch/            Issue tracker: one folder per piece of work
  <feature-slug>/
    spec.md
    issues/01-<slug>.md
```

## Documentation index

Start here if you are a new contributor or coding agent:

1. [Requirements specification](docs/requirements/requirements.md)
2. [Game design specification](docs/design/game-design-spec.md)
3. [Software architecture](docs/architecture/software-architecture.md)
4. [Coding standards](docs/architecture/coding-standards.md)
5. [Roadmap](docs/roadmap/roadmap.md)
6. [Test strategy](docs/testing/test-strategy.md)
7. [ADR-0001: Engine & language selection](docs/adr/0001-engine-and-language-selection.md)
8. [Issue tracker (`.scratch/`)](docs/agents/issue-tracker.md)
9. [Archived feature folders](docs/history/features/README.md)
10. [Playtest 001 script](docs/testing/playtest-001.md)

## Development workflow

- Coding agents use [Matt Pocock's skills](https://github.com/mattpocock/skills),
  vendored as project skills in `.claude/skills/` so they load in every
  session, cloud or local (`tools/sync_skills.sh` updates them, pinned in
  `.claude/skills/UPSTREAM`). Larger work goes
  `/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement`.
- Work is tracked as local markdown issues in `.scratch/<feature-slug>/`
  (a `spec.md` plus one file per ticket in `issues/`). See
  [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md).
- Features 000&ndash;048 used the older five-file folders; they are archived,
  read-only, in [`docs/history/features/`](docs/history/features/README.md).
- Small fixes and tweaks can be made directly without a feature folder, but
  documentation and tests should still be kept in sync.
- Architectural decisions go into `docs/adr/` as ADRs.
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
| 8     | Save/load (autosave at dawn, Continue)     | done (feature 020) |
| 8     | Save/load prototype                        | planned |

Full detail in [`docs/roadmap/roadmap.md`](docs/roadmap/roadmap.md).

## License

To be decided. The project intends to remain free / open-source friendly.
No copyrighted third-party assets are used.
