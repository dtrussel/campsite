# Feature 031: Handoff

**Done:** milestone 0, which covers the references, their index and the style guide.

**Next:** milestone 1 (code only, no Blender needed):
- `world_lighting.gd` palettes;
- the TestWorld and title Environments;
- a new `shaders/post_tiltshift.gdshader` with `scripts/world/post_fx.gd`;
- camera FOV and distance in `camera_follow.gd`.

Then milestone 2 (ground and flora) and milestone 3 (camp props), which need `tools/setup_blender.sh`.

**Environment notes:**
- Neither Godot nor Blender was installed in the cloud session. Download Godot 4.3-stable the way `.github/workflows/build.yml` does to run `tools/check.sh`.
- The renderer is GL Compatibility, so there is no SSAO and no built-in DOF.

**Open question:** should any new decor prop gain gameplay, such as the well as a water source? Not in this pass.
