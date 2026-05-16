# Feature 000: Decisions

**Feature:** Project Bootstrap

---

## Decision Log

### DEC-000-001: Engine selection — Godot 4 + GDScript
**Date:** 2026-05-16
**Decision:** Use Godot 4.x with GDScript.
**Rationale:** See full analysis in `docs/decisions/ADR-0001-engine-and-language-selection.md`. Summary: free/open-source, suitable for stylized 3D, agent-friendly, no build step, simple project structure, strong editor integration.
**Alternatives rejected:** Godot+C#, Unity, Unreal, MonoGame, Bevy.

---

### DEC-000-002: Single global resource inventory
**Date:** 2026-05-16
**Decision:** All resources are held in a single global inventory in ResourceManager, not per-character inventories.
**Rationale:** The prototype does not need per-character carrying capacity. A single inventory simplifies gathering, spending, and HUD display significantly. Per-character inventories can be added in a later phase if game design requires it.
**Risk:** If the design later requires companions to carry resources to a storage building, a refactor of ResourceManager will be needed. This is acceptable for Phase 0.

---

### DEC-000-003: No navigation mesh in skeleton
**Date:** 2026-05-16
**Decision:** The Phase 0 skeleton does not implement NavigationServer3D or navigation meshes.
**Rationale:** Navigation is not needed until Phase 4 (companions) and Phase 5 (mobs). Adding it now would add complexity without providing value. Simple direct movement (toward a target position) is sufficient for the skeleton.
**Impact on future work:** Phase 4 (companion) and Phase 5 (mob) agents must add navigation mesh to TestWorld and NavigationAgent3D to companion/mob scenes.

---

### DEC-000-004: Placeholder geometry only — no external art assets
**Date:** 2026-05-16
**Decision:** All meshes in Phase 0 use Godot's built-in CSG nodes or primitive MeshInstance3D nodes. No external 3D assets are used.
**Rationale:** Art assets are not available at bootstrap. Placeholder geometry is sufficient to prove the project opens, runs, and shows a scene. Art is deferred to a later phase.
**Note:** Final art style reference is documented in `docs/design/game-design-spec.md` section L.

---

### DEC-000-005: Autoloads registered in project.godot directly
**Date:** 2026-05-16
**Decision:** Autoloads are registered in `project.godot` using the `[autoload]` section. Scripts are stubs initially.
**Rationale:** Registering them now establishes the global service names that all future scenes and scripts will reference. Stub implementations prevent null reference errors. Agents can fill in real implementations without changing the registration.

---

### DEC-000-006: HUD shows all 10 resources from day one
**Date:** 2026-05-16
**Decision:** The HUD displays all 10 resource types immediately, even if most are at 0.
**Rationale:** This establishes the UI contract early, allows future phases to simply update counts rather than add new UI elements, and communicates the full resource system to playtesters from the first run.

---

### DEC-000-007: Day/night visual only in Phase 0 skeleton
**Date:** 2026-05-16
**Decision:** The skeleton includes a TimeManager stub that advances time of day, but only visual/UI changes result (no gameplay effects). Actual day/night gameplay is Phase 5.
**Rationale:** Having a time counter running from day one makes the HUD feel live and proves the signal architecture without needing mob or combat systems.
