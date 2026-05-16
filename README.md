# Campsite Chronicles

> **Status:** Pre-production / Prototype Bootstrap (Phase 0)

A stylized 3D base-builder and survival defense game. A 7-year-old boy goes camping with his family in the woods. During the day you explore, gather, craft, and build. At night, evil forest mobs attack your campsite. Protect your family, survive the night, and turn a fragile camp into a magical woodland fortress.

---

## Technology Stack

| Component | Choice |
|-----------|--------|
| Engine    | Godot 4.x |
| Language  | GDScript (typed) |
| Target    | Windows desktop first |
| Rendering | Compatibility / Forward+ (stylized 3D) |
| License   | MIT |

See [ADR-0001](docs/decisions/ADR-0001-engine-and-language-selection.md) for the engine/language decision rationale.

---

## How to Open the Project

1. Install [Godot 4.x](https://godotengine.org/download) (4.2 or later recommended).
2. Open Godot and choose **Import**.
3. Navigate to `game/project.godot` and click **Open**.
4. Let Godot import assets on first load.

## How to Run the Main Scene

- Press **F5** in the Godot editor, or
- Go to **Project → Run Project** (the main scene is `scenes/main/Main.tscn`).

---

## Repository Structure

```
campsite/
├── game/                   # Godot 4 project root
│   ├── project.godot
│   ├── scenes/             # All .tscn scene files
│   │   ├── main/           # Entry-point scene
│   │   ├── player/         # PlayerBoy scene
│   │   ├── companions/     # Companion scenes
│   │   ├── mobs/           # Mob scenes
│   │   ├── base/           # CampfireCore and base objects
│   │   ├── buildings/      # Placeable building scenes
│   │   ├── resources/      # Resource node scenes
│   │   ├── ui/             # HUD and menu scenes
│   │   └── world/          # World/map scenes
│   ├── scripts/            # All .gd script files
│   │   ├── core/           # Global managers (GameManager, etc.)
│   │   ├── game_loop/      # TimeManager, wave logic
│   │   ├── player/         # Player controller
│   │   ├── companions/     # Companion controller, tasks
│   │   ├── mobs/           # Mob controller, AI
│   │   ├── base/           # Base/campfire logic
│   │   ├── buildings/      # Building placement, behavior
│   │   ├── resources/      # Resource nodes, gathering
│   │   ├── crafting/       # Crafting system
│   │   ├── progression/    # XP, leveling
│   │   ├── ui/             # HUD, menus
│   │   ├── save/           # Save/load
│   │   └── utilities/      # Shared helpers
│   ├── assets/             # Raw asset files
│   └── resources/          # Godot .tres resource data files
│       ├── game_data/
│       ├── buildings/
│       ├── items/
│       ├── mobs/
│       └── companions/
├── docs/                   # Project documentation
│   ├── requirements/       # Requirements specification
│   ├── architecture/       # Software architecture, coding standards
│   ├── design/             # Game design specification
│   ├── roadmap/            # Development phases and roadmap
│   ├── decisions/          # Architecture Decision Records (ADRs)
│   └── testing/            # Test strategy
├── tools/                  # Helper scripts and pipeline tools
└── .features/              # Feature-level planning and agent handoff
    └── 000-project-bootstrap/
```

---

## Documentation Index

| Document | Purpose |
|----------|---------|
| [Requirements](docs/requirements/requirements.md) | Full product requirements |
| [Game Design Spec](docs/design/game-design-spec.md) | Detailed game design |
| [Software Architecture](docs/architecture/software-architecture.md) | Technical architecture |
| [Coding Standards](docs/architecture/coding-standards.md) | Code style guide |
| [Roadmap](docs/roadmap/roadmap.md) | Development phases |
| [ADR-0001](docs/decisions/ADR-0001-engine-and-language-selection.md) | Engine/language decision |
| [Test Strategy](docs/testing/test-strategy.md) | Testing approach |

---

## Development Workflow

1. Pick the next phase from [roadmap.md](docs/roadmap/roadmap.md).
2. Check `.features/` for an existing feature folder or create one.
3. Read the `handoff.md` from the previous session.
4. Implement the feature incrementally.
5. Update `status.md` and `handoff.md` before finishing.

See [.features/README.md](.features/README.md) for the full agent workflow.

---

## Roadmap Summary

| Phase | Goal | Status |
|-------|------|--------|
| 0 | Project foundation | **In progress** |
| 1 | Playable movement and camp scene | Planned |
| 2 | Resources and gathering | Planned |
| 3 | Building placement | Planned |
| 4 | Companion prototype | Planned |
| 5 | Day/night cycle and first mob wave | Planned |
| 6 | Combat, XP, and leveling | Planned |
| 7 | Crafting and first survival loop | Planned |
| 8 | Save/load prototype | Planned |

Full details: [roadmap.md](docs/roadmap/roadmap.md)

---

## License

MIT — see LICENSE file when added.
