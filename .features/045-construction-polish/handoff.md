# Feature 045: Handoff

- **New hand tools:** add the glb to `CharacterVisual.TOOLS` (grip at the origin, handle +Y, head along X) and call `show_tool(&"key")`. Parts that would clash go in `HeroDefinition.tool_hidden_parts`.
- **New buildings:** the blueprint look is automatic for painted models. Non-painted (StandardMaterial3D) surfaces are not clipped, and stay fully visible under the ghost.
- **Tuning:**
  - `BuildBeat.HAMMER_SPEED`, `FETCH_SPEED` and `IMPACT_AT`.
  - Ghost colour and alpha are in `blueprint_ghost.gdshader`.
  - `Building.BLUEPRINT_START_HEIGHT`, `PILE_PIECES` and `MAX_PILE_PIECES`.
- **Open:** hand-play the companion building with her lantern hidden, and a save/load of a half-built blueprint (the code path re-dresses it in `_enter_blueprint`).
