# Feature 032: Handoff

**Done:** see `status.md`. The concept and the map are in `plan.md`.

**Where things live:**
- **The plan:** `game/scripts/world/world_layout.gd`. Change grove circles, paths and the pond here; the ground shader follows automatically.
- **Grove dressing:** `world_dressing.gd`, in `_build_pine_grove`, `_build_pond`, `_build_woodlot`, `_build_berry_hollow` and `_build_ferns`.
- **Resource positions:** the `Resources` nodes in `TestWorld.tscn`. Keep them in their grove circles and out of the lanes. `map_overview.tscn` prints each node's clearances.
- **Review renders:**
  - Run `xvfb-run -a godot --path game --resolution 1600x900 res://tests/sim/map_overview.tscn -- <out_dir>/`.
  - It writes `plan.png`, the oblique views and `game_*.png` views per grove.

**Open / ideas:**
- Measure the frame rate on a real GPU. The scene has more models now: about 25 grove pieces, plus ferns and reeds as cheap MultiMeshes.
- A stream from the pond out through the NE wall, and a plank bridge (concept 10).
- An occlusion fade for trees between the camera and the kids would allow taller southern groves.
