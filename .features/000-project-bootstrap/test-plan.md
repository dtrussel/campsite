# Feature 000: Test Plan

**Feature:** Project Bootstrap

---

## Acceptance Criteria

### AC-000-01: Project opens without errors
**Setup:** Godot 4.2+ installed. Open `game/project.godot`.
**Steps:**
1. Launch Godot and import `game/project.godot`.
2. Wait for asset import to complete.
3. Check the Output panel.
**Expected:** No errors in the Output panel. All scripts load without parse errors.
**Pass:** Zero error lines in Output on startup.

---

### AC-000-02: Main scene runs
**Setup:** Project open in Godot.
**Steps:**
1. Press F5 to run the main scene.
2. Wait for 5 seconds.
**Expected:** A 3D scene renders. A player placeholder is visible. A campfire placeholder is visible.
**Pass:** Scene renders without crashing. No error/warning spam in Output.

---

### AC-000-03: Player placeholder is visible
**Setup:** Main scene running.
**Steps:**
1. Observe the 3D viewport.
**Expected:** A distinct mesh (capsule, box, or simple shape) represents the player.
**Pass:** Player mesh visible and distinguishable from the ground.

---

### AC-000-04: HUD renders
**Setup:** Main scene running.
**Steps:**
1. Observe the screen overlay (HUD).
**Expected:** A UI panel or labels are visible showing:
- Time of day (or day number)
- Base health (even if placeholder value)
- At least some resource labels
**Pass:** HUD visible; at minimum: time display and resource labels render.

---

### AC-000-05: All 10 resource names visible in HUD
**Setup:** Main scene running.
**Steps:**
1. Observe the HUD resource area.
**Expected:** All 10 resource names are shown: Wood, Stone, Berries, Fiber, Mushrooms, Clay, Leaves, Resin, Scrap, Glow Shards.
**Pass:** All 10 names visible in HUD (counts may be 0).

---

### AC-000-06: Campfire core placeholder visible
**Setup:** Main scene running.
**Steps:**
1. Observe the world.
**Expected:** A distinct mesh or object represents the campfire core at the center of the camp area.
**Pass:** Campfire object visible; distinct from ground/terrain.

---

### AC-000-07: No null reference errors in first 10 seconds
**Setup:** Main scene running.
**Steps:**
1. Run for 10 seconds without pressing any keys.
2. Watch Output panel.
**Expected:** No `null reference`, `Invalid call`, or `Index out of range` errors.
**Pass:** Clean output for 10 seconds of idle.

---

### AC-000-08: Autoloads registered
**Setup:** Project open.
**Steps:**
1. Go to Project → Project Settings → Autoload.
**Expected:** At minimum these autoloads listed:
- GameManager
- TimeManager
- ResourceManager
- ProgressionManager
**Pass:** All four autoloads visible in settings.

---

### AC-000-09: Documentation is readable
**Setup:** Repository cloned.
**Steps:**
1. Open `README.md`.
2. Open `docs/requirements/requirements.md`.
3. Open `docs/design/game-design-spec.md`.
4. Open `docs/architecture/software-architecture.md`.
5. Open `docs/roadmap/roadmap.md`.
**Expected:** All files open and are readable markdown with no broken sections.
**Pass:** All five files readable; no obviously truncated content.

---

### AC-000-10: Handoff file is complete
**Setup:** Repository cloned.
**Steps:**
1. Open `.features/000-project-bootstrap/handoff.md`.
**Expected:** File contains: current status, list of created files, technology choice, known limitations, next recommended feature, open questions, how to open/run the project.
**Pass:** All sections present and filled in with real content.

---

## Failure Triage

| Symptom | Likely Cause | Where to Look |
|---------|-------------|--------------|
| Script parse error on startup | Syntax error in a .gd file | Output panel shows file and line |
| Scene fails to instantiate | Missing @export node reference or invalid path | Error in Output; check inspector |
| HUD not visible | HUD scene not in Main.tscn or wrong layer | Main.tscn scene tree; CanvasLayer check |
| Autoload not found error | Autoload not registered in project.godot | Project Settings → Autoload |
| Player not visible | Scene not instanced or mesh not assigned | Main.tscn → Characters → PlayerBoy |
