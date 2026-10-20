# Feature 045: Decisions

- **The ghost is a material, not node transparency.** `GeometryInstance3D.transparency` does not show in the Compatibility renderer (044), but an alpha-blended unshaded ShaderMaterial does. Each blueprint gets its own ghost material, so plain uniforms (`clip_y`, `hit_flash`, `fade`) work without instance uniforms.
- **The solid part is clipped, not sunk.** Sinking showed the top of the model at ground level, which read as a buried finished building. A separate shader (`painted_prop_build`) cuts the painted look above the build line. It is used only while a building is a blueprint, so the shared `painted_prop` shader stays free of `discard`. The outline pass is dropped during construction.
- **Clip heights are world-space.** Buildings are moved after `_ready` (BuildManager and the save loader), so `_refresh_construction()` also runs deferred once. Buildings only turn about Y, so the line is `global_position.y` plus the model's local height span.
- **The site is built from simple boxes in Godot** (styled as props), not a new art asset: it is on screen for a few seconds and sinks away.
- **The mallet is one glb shared by both heroes**, held on `handslot.r` in the bone's own frame: the handle comes forward out of the fist, the head runs along the forearm, and it is scaled 1.9× so it reads from the game camera. Leo's stick and Nela's lantern are hidden while it is out (`HeroDefinition.tool_hidden_parts`).
- **Progress stays per frame.** BuildBeat only drives animation and hit feedback, so build times and the 044 tests do not depend on clip lengths.
