# Campsite (working title)

> A stylized 3D base-builder / survival defense game about a 7-year-old boy
> protecting his family campsite from evil forest mobs that emerge at night.

## Pitch

By day you explore the woods, gather resources, craft tools, improve the
campsite, and assign tasks to family members and pets. At sunset, the forest
turns hostile: evil mobs swarm the camp and you must defend the campfire, the
tent, your family, and yourself. Survive the night, level up, and turn a
fragile camping trip into a magical woodland fortress.

## Status

**Pre-production / prototype bootstrap.**

The repository currently contains:

- Full documentation foundation (vision, requirements, design, architecture,
  roadmap, decisions, testing strategy, coding standards).
- A minimal runnable Godot 4 / GDScript skeleton: main scene, test world,
  placeholder boy character with basic movement, placeholder campfire core,
  placeholder HUD listing all 10 resources, and a top-down/isometric camera.
- The agent feature workflow under `.features/`.

There is **no gameplay yet** beyond walking around a flat test world. See
[`docs/roadmap/roadmap.md`](docs/roadmap/roadmap.md) for the planned phases.

## Technology stack

- **Engine:** Godot 4.x (4.2+ recommended)
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

## How to run the main scene

- Press **F5** in the Godot editor, or use **Project > Run**.
- The configured main scene is `game/scenes/main/Main.tscn`, which loads the
  test world, spawns the placeholder boy, and shows the placeholder HUD.

Controls (prototype):

- **W / A / S / D** &mdash; move the boy.
- **Esc** &mdash; quit (placeholder).

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
    art/              Final art (later)
    audio/            Sound effects and music
    materials/        Shared materials
    fonts/            Fonts
  resources/          Godot .tres data resources (data-driven content)
    game_data/        Global tuning resources
    buildings/        Building definitions
    items/            Item / resource definitions
    mobs/             Mob definitions
    companions/       Companion definitions
  tests/
    manual/           Manual playtest checklists and smoke scenes
    automated/        Script-level tests (later)

/docs/                Project documentation
  requirements/       Product and functional requirements
  architecture/       Software architecture and coding standards
  design/             Game design specification
  roadmap/            Phased roadmap
  decisions/          Architecture decision records (ADRs)
  testing/            Test strategy and checklists

/tools/               Helper scripts, build tooling, dev utilities (later)

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
9. [Bootstrap feature handoff](.features/000-project-bootstrap/handoff.md)

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

| Phase | Goal                                       |
|-------|--------------------------------------------|
| 0     | Project foundation (this commit)           |
| 1     | Playable movement and camp scene           |
| 2     | Resources and gathering                    |
| 3     | Building placement                         |
| 4     | Companion prototype                        |
| 5     | Day/night cycle and first mob wave         |
| 6     | Combat, XP, and leveling                   |
| 7     | Crafting and first survival loop           |
| 8     | Save/load prototype                        |

Full detail in [`docs/roadmap/roadmap.md`](docs/roadmap/roadmap.md).

## License

To be decided. The project intends to remain free / open-source friendly.
No copyrighted third-party assets are used.
