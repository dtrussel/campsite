# Feature 045: Handoff

- **New hand tools:** add the glb to `CharacterVisual.TOOLS` (grip at the origin, handle +Y, head along X) and call `show_tool(&"key")`. Parts that would clash go in `HeroDefinition.tool_hidden_parts`.
- **New buildings:** the blueprint look is automatic for painted models. Non-painted (StandardMaterial3D) surfaces are not clipped, and stay fully visible under the ghost.
- **Tuning:**
  - `BuildBeat.HAMMER_SPEED`, `FETCH_SPEED` and `IMPACT_AT`.
  - Ghost colour and alpha are in `blueprint_ghost.gdshader`.
  - `Building.BLUEPRINT_START_HEIGHT`, `PILE_PIECES` and `MAX_PILE_PIECES`.
- **Tested:** Nela building with her lantern put away, and Continue with a half-built blueprint (smoke `_run_blueprint_save_scenario`).
- **Smoke fix:** the bark scenario's "Nela played" step now closes any story card and stuns the gremlin before the steal. Without that, depending on what ran before, the first-gremlin story card held the bark back, or the gremlin was freed before the test hit it. The second case segfaults Godot 4.3 when a method is called through a typed variable that holds a freed object.
