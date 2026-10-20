# Feature 048: Handoff

- Rebuild with `.venv-blender/bin/python art/characters/little_golem.py` (about 30 s).
  - `QUICK=1` renders clay views.
  - `MEASURE=1` prints the landmark table and writes `build/art_previews/little_golem_sil_{front,side}.png`.
- Sheet numbers live in `SHEET` at the top of the script. The parts behind each landmark are tagged with `mark()`.
- The GLB nodes are `Body` (+ `Body_Window`, `Body_Moon`), `Head` (+ `Head_Eyes`, pivot at the chin), `ArmL` and `ArmR` (pivots at the shoulders). If you rename one, update `game/scripts/story/little_golem.gd`.
- The model gallery (`game/tools/model_gallery.tscn`) shows the raw GLB without `LittleGolem`'s glow materials. To check the glows, instance `LittleGolem` itself.
