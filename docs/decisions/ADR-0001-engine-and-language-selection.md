# ADR-0001: Engine and language selection

- **Status:** Accepted
- **Date:** 2026-05-16
- **Deciders:** Project owner; bootstrap agent
- **Supersedes:** &mdash;
- **Superseded by:** &mdash;

## Context

We are starting a new stylized 3D base-builder / survival defense game. The
player controls a 7-year-old boy who must protect a family campsite from
evil forest mobs at night. The project must:

- run on Windows desktop first;
- support stylized 3D with strong silhouettes and readable top-down/iso play;
- support base building, resource gathering, crafting, simple AI companions,
  mobs, day/night cycle, and incremental progression;
- be easy to iterate on by both humans and coding agents;
- remain free / open-source friendly with no costly licenses;
- avoid heavy dependencies and complex toolchains where possible.

We must pick an engine and primary language now, because the choice shapes
the entire project structure, asset pipeline, and contributor workflow.

## Options considered

### 1. Godot 4 + GDScript

- **Cost / licensing:** MIT-licensed engine. Zero royalties.
- **Stylized 3D suitability:** Good. Godot 4 has a modern renderer, signed
  distance fields, GI, decent material/shader support, and good support for
  low-poly stylized 3D.
- **Base-building / survival suitability:** Good. Scenes-as-prefabs map well
  to buildings, resource nodes, mobs, companions. Resource files (`.tres`)
  are an excellent fit for data-driven recipes, items, and mobs.
- **Editor / tooling:** Solid editor, fast iteration, integrated debugger,
  scene/animation/tilemap tools.
- **Agent friendliness:** Excellent. Plain-text scenes (`.tscn`) and scripts
  (`.gd`) are easy for coding agents to read and modify. No project-file
  binary blobs.
- **Asset pipeline:** Native importers for glTF, OBJ, PNG, OGG, WAV. Good
  enough for stylized 3D.
- **Export / platforms:** Native Windows export, plus Linux, macOS, web,
  mobile. No additional licensing.
- **Maintainability:** Engine and language are tightly integrated. Less
  cross-language friction.
- **Learning curve:** Low. GDScript is Python-like and the editor surfaces
  the relevant abstractions.
- **Custom engine work required:** Minimal.

### 2. Godot 4 + C#

- **Cost / licensing:** Same MIT engine. C# bindings free.
- **Stylized 3D suitability:** Same as GDScript option.
- **Base-building suitability:** Equivalent.
- **Editor / tooling:** Requires the .NET edition of Godot and a working
  .NET 6/8 SDK. External IDE (Rider, VS, VS Code) is effectively required
  for productive C# work. More moving parts.
- **Agent friendliness:** Worse than GDScript. Two languages in the same
  project (GDScript is still needed for some integrations, plus C#),
  separate build step, NuGet, .csproj/.sln files.
- **Asset pipeline:** Same.
- **Export:** Requires the Mono/.NET export templates. Slightly heavier.
- **Maintainability:** Bigger surface area; binding generation tied to
  Godot versions.
- **Learning curve:** Higher.
- **Custom engine work:** Minimal, but more setup overhead.

### 3. Unity

- **Cost / licensing:** Free at small revenue, but past licensing churn
  (Runtime Fee, terms changes) is a meaningful risk for an indie project.
  Not as friendly to free/open-source distribution.
- **Stylized 3D suitability:** Excellent. URP/HDRP, Shader Graph, vast
  ecosystem.
- **Base-building suitability:** Excellent.
- **Editor / tooling:** Best-in-class in many ways, but heavy install and a
  big editor footprint.
- **Agent friendliness:** Mediocre. Binary `.meta`/`.unity`/`.prefab` files
  are YAML but verbose; serialization quirks are easy to break with raw
  edits. Two languages effectively in play (C# + ShaderLab).
- **Asset pipeline:** Mature.
- **Export:** Mature, but with licensing strings attached.
- **Maintainability:** Vendor lock-in concerns.
- **Learning curve:** Medium.
- **Custom engine work:** Minimal.

### 4. Unreal Engine 5

- **Cost / licensing:** Royalty after revenue threshold. Source available.
  More restrictive than Godot for free/open-source distribution.
- **Stylized 3D suitability:** Excellent, but defaults trend
  photorealistic. Achievable but heavier.
- **Base-building suitability:** Good. Heavier ramp-up.
- **Editor / tooling:** Very capable, but very heavy.
- **Agent friendliness:** Poor. Binary uassets, blueprints stored as
  binary, deep C++ engine surface, build times.
- **Asset pipeline:** Mature, but heavy.
- **Export:** Mature.
- **Maintainability:** Engine upgrades are non-trivial.
- **Learning curve:** Steepest.
- **Custom engine work:** Possible but expensive.

### 5. MonoGame

- **Cost / licensing:** Free, MIT.
- **Stylized 3D suitability:** Possible but requires writing a lot of
  rendering and scene code from scratch.
- **Base-building suitability:** Possible, but no scene editor &mdash; you
  build editors and tooling yourself.
- **Editor / tooling:** Effectively none out of the box.
- **Agent friendliness:** Code-only, which agents can handle, but the
  amount of custom engine work means progress is slow.
- **Asset pipeline:** Manual.
- **Export:** Manual.
- **Maintainability:** You own a lot more.
- **Learning curve:** High in practice because of the missing tooling.
- **Custom engine work:** Very high.

### 6. Bevy

- **Cost / licensing:** Free, MIT/Apache. Pure Rust ECS engine.
- **Stylized 3D suitability:** Improving but immature in 3D editor tooling.
- **Base-building suitability:** Possible but data-only editors today.
- **Editor / tooling:** No mature editor yet; everything is code.
- **Agent friendliness:** Code-only is fine, but the lack of an editor and
  the rapid API churn between versions hurt agent iteration.
- **Asset pipeline:** Functional, but more manual than Godot.
- **Export:** Cross-platform, Windows export works.
- **Maintainability:** API churn risk is real.
- **Learning curve:** Highest in this list once Rust&rsquo;s borrow checker is
  added.
- **Custom engine work:** Moderate to high.

## Decision

**We choose Godot 4 with GDScript** as the engine and primary language for
this project.

### Why GDScript specifically

- It is Godot-native: editor integration, autocomplete, signals, scene
  references, and exported variables all work first-class.
- It keeps the project to a single language and a simple, plain-text
  repository structure that coding agents can read and edit reliably.
- It removes the .NET/Mono dependency entirely: no extra SDK, no extra
  export templates, no `.csproj`/`.sln` to maintain.
- It enables very fast iteration: edits in `.gd` files are picked up
  immediately by the running editor.
- It lowers project setup complexity for new contributors and CI.
- It is more than fast enough for the planned first vertical slice. We do
  not anticipate large simulations until well after the prototype.

### Why not C#

- The added complexity is not justified at this stage.
- We do not have a performance bottleneck that GDScript cannot address.
- The shared-team productivity loss of a second language and toolchain
  outweighs the small per-frame gains for a stylized prototype.
- Coding agents working on `.cs` files would also need to maintain build
  system metadata, which is a friction we can avoid entirely.

## Consequences

### Positive

- Lowest setup friction. Open the project in Godot and run.
- Plain-text repository that is friendly to coding agents and `git diff`.
- One language, one editor, one debugger.
- Easy onboarding for new contributors.
- Free, no royalties, no vendor lock-in.

### Negative / risks

- **GDScript performance ceiling.** Tight inner loops with hundreds of
  simulated entities may eventually need optimization. Mitigation:
  - Pool mobs and projectiles instead of instancing/freeing.
  - Keep per-frame allocations low; reuse arrays.
  - Push expensive computation to fewer entities and longer ticks (e.g.
    AI re-planning every N frames, not every frame).
  - If we ever hit a real wall, port hot code to `GDExtension` (C++) or
    isolate it behind a service so it can be swapped without rewriting
    game logic.
- **Large mob counts.** Same mitigation applies; design night waves to
  target tens, not thousands, of mobs at once.
- **3D asset pipeline discipline.** Godot&rsquo;s 3D pipeline is good, but
  requires care with units, scale, materials, and import settings. We will
  document import conventions before bringing in non-placeholder art.
- **Multiplayer.** Not in scope. If we ever add it, architectural care is
  required (especially around `ResourceManager`, `BuildManager`, and
  authoritative state). The autoload-singleton pattern makes a future
  client/server split harder; if multiplayer becomes a real goal, the
  singletons must be revisited.
- **Save / load.** Save format must be designed early so we don&rsquo;t
  encode raw scene references or unstable identifiers. ADR or design note
  to follow when the first save format is committed.
- **GDScript static typing.** We will use static typing wherever practical
  to keep tooling helpful and bugs cheap, even though GDScript allows
  dynamic typing.

### Neutral

- We accept that GDScript code is engine-coupled. Porting away from Godot
  later would require a rewrite. This is an acceptable trade-off for the
  iteration speed and simplicity gained today.
