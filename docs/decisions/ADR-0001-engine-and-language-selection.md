# ADR-0001: Engine and Language Selection

**Date:** 2026-05-16
**Status:** Accepted
**Deciders:** Project bootstrap agent

---

## Context

We are starting a new stylized 3D base-builder/survival defense game targeting Windows desktop first, with a small/indie-scale team, designed for agent-driven development and fast iteration. We need to select an engine and primary scripting language before any implementation begins.

---

## Options Evaluated

### 1. Godot 4 + GDScript ✅ Selected

**Cost/Licensing:** Free, MIT license. No royalties, no subscription, no revenue share.

**Stylized 3D:** Godot 4 offers Forward+ and Compatibility renderers. The stylized/non-photorealistic look this project targets is well-served by its shader system, environment system, and toon-style rendering capabilities. Not as powerful as Unreal for photorealism, but that's not a goal here.

**Base-building / survival gameplay:** Godot's scene/node system maps well to placeable buildings, entity-component-like design, and day/night state machines. The engine has no major gaps for this genre.

**Editor/tooling quality:** Godot 4's editor is mature, stable, and self-contained. Built-in 3D tools, shader editor, animation player, and resource system are all usable for this project scale.

**Simplicity for coding agents:** GDScript is Python-like, terse, and readable. Godot-native idioms (signals, resources, autoloads) are easy to follow and extend. No build step required. Minimal boilerplate. Agents can modify scripts and scenes quickly.

**Asset pipeline:** Supports GLTF, OBJ, and FBX imports. Texture formats, materials, and shaders are all manageable. For placeholder art and stylized 3D, this is more than sufficient.

**Export/platform:** Godot 4 supports Windows, macOS, Linux, Android, iOS, and web exports. Windows is the primary target; other platforms are not blocked.

**Long-term maintainability:** GDScript is readable, well-documented, and closely tied to Godot's API. The Godot Foundation controls both, so compatibility is expected to remain high within major versions.

**Learning curve:** Low to medium for new contributors. GDScript is approachable. Godot's documentation is strong.

**Custom engine/tooling:** Minimal. Godot provides what this project needs out of the box.

---

### 2. Godot 4 + C#

**Pros:** Type safety, existing .NET ecosystem, potentially faster execution for complex simulations.

**Cons:** Requires .NET SDK installation. Adds complexity to the build environment. `.csproj` and `.sln` files increase repository noise. C# in Godot 4 requires the mono/dotnet template exports, which are larger and have additional platform constraints. Agents must navigate two file types and two toolchains. Code completion and tooling require a separate IDE or plugin. **Performance gains are not needed at the prototype stage and possibly not at the full game scale for this genre.** The added dependency is a real cost for agent-driven, fast-iteration development.

**Decision:** Rejected. The GDScript option covers all requirements without the overhead.

---

### 3. Unity

**Pros:** Mature ecosystem, large asset store, strong 3D tooling, large community.

**Cons:** Commercial licensing complications introduced in 2023 (per-install fees, pricing changes). Runtime fee model creates uncertainty for indie/open-source projects. Requires C# (acceptable language, but bound to Unity's framework). Larger project setup. Less transparent engine code. Not free/open-source. Heavier editor. Not aligned with the project's open-source-friendly requirement.

**Decision:** Rejected. Licensing risk and closed-source nature are disqualifying for this project.

---

### 4. Unreal Engine

**Pros:** Industry-leading 3D rendering, Nanite, Lumen, strong toolchain for AAA.

**Cons:** Blueprint + C++ dual workflow is complex for agents. C++ compilation cycles are slow. Project setup is heavy. Royalty (5% over $1M revenue) is fine for large studios but adds overhead for indie. Designed for photorealistic fidelity — overkill for stylized 3D. Steep learning curve. Large engine binary in repo is impractical. Binary assets make diffs and agent workflows harder.

**Decision:** Rejected. Massive over-engineering for this game's scale and style goals.

---

### 5. MonoGame

**Pros:** Lightweight, flexible, fully open source, C#, good for 2D/2.5D.

**Cons:** No editor — all tooling must be custom-built. 3D support is limited and not the focus. Asset pipeline requires external tools. No built-in scene graph, physics, or UI system. Very high implementation overhead for features Godot provides for free.

**Decision:** Rejected. Too low-level for a game that needs a full 3D scene system, physics, UI, and asset pipeline.

---

### 6. Bevy (Rust)

**Pros:** Modern ECS architecture, excellent performance, fully open source, growing community.

**Cons:** Rust has a steep learning curve. Bevy is still maturing (frequent breaking API changes as of 2024-2026). No WYSIWYG editor. Asset pipeline is minimal. 3D tooling is far behind Godot or Unity. Not a practical choice for a game design that needs fast visual iteration. Agent-driven development in Rust is harder due to borrow checker constraints and unfamiliar patterns.

**Decision:** Rejected. Not suitable for fast iteration or stylized 3D with an accessible dev workflow.

---

## Decision

**Godot 4 + GDScript.**

### Rationale for GDScript over C# in Godot

| Criterion | GDScript | C# in Godot |
|-----------|----------|-------------|
| Repository noise | Minimal | Adds .csproj, .sln, obj/ |
| Setup dependency | None beyond Godot | .NET SDK required |
| Export complexity | Standard Godot template | Mono/dotnet template (larger, more constraints) |
| Agent readability | High — Python-like | Moderate — standard C# |
| Editor integration | Full — GDScript is first-class | Good, but requires dotnet plugin |
| Performance at prototype | More than sufficient | Marginally faster |
| Performance risk at scale | Real — noted below | Lower |
| Iteration speed | Fastest — no compile step | Slower — build step required |
| Project structure | Single language, single toolchain | Dual toolchain |

---

## Consequences and Known Risks

| Risk | Likelihood | Mitigation |
|------|-----------|-----------|
| GDScript performance bottlenecks with hundreds of mobs | Medium | Use object pooling, limit active mob count, profile before optimizing |
| Large simulation (pathfinding, many agents) may need optimization | Medium | Design mob system with pooling from Phase 5; consider GDNative or C# for specific hot paths only if profiling proves it necessary |
| 3D asset pipeline discipline required | Medium | Enforce GLTF import standards; document conventions early |
| Save/load data model must be stable | Low-Medium | Version save data from the start; avoid saving direct node references |
| Future multiplayer would require significant architectural work | Low (not in scope) | Design state via managers (not scene-coupled) to ease future refactoring |

---

## Review Triggers

This decision should be revisited if:
- Profiling shows GDScript cannot sustain target frame rate with planned mob counts.
- A required platform requires C# or native plugins that GDScript cannot drive.
- A core team member with strong C# expertise joins and the complexity cost of dual-language is accepted.
