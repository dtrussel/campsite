# Feature 015: Game-budget kids (reduce the polygon budget)

## Context
The user asks: other games' characters use far fewer polygons, so should the budget come down, and to what?

**Current state:** Leo has 114k triangles and Nela 119.3k, against a ~120k budget. Reference points:
- League of Legends champions: about 7–10k, with 512–1k textures;
- WoW-style characters: about 5–15k.

**Answer: yes. Reduce to about 35k triangles per kid, with an aggressive option of about 20k.**
- **Screen size.** The top-down camera shows the kids at about 80–100 px tall, and HUD portraits are 128 px. Even at 35k, several triangles already share one pixel, so the extra triangles are invisible.
- **The outline doubles the cost.** The inverted-hull outline (`outline.gdshader`) draws every mesh a second time, so 120k triangles are really 240k per kid. Web or low-end playtest machines feel this.
- **It fits the drawn look better.** Fewer, broader planes read as "painted". Detail belongs in the texture, as the research concluded.
- **Download and load time.** GLB size is roughly proportional to vertices. Smaller files also mean faster imports and LOD generation.
- **Bake time barely changes.** Texture size and samples drive bake time, not triangles. Faster iterations come from the draft bake (`BAKE_SIZE`), not from this.

**Why the meshes are dense today.** Colours are per-vertex (`color_by` / `grime` → `Col`), so painted stripes, folds and face-adjacent shading need dense undecimated meshes to stay crisp:
- the shorts and pants are undecimated voxel remeshes;
- the head loft has 100 × 96 vertices.

**Key enabler: a high-to-low bake.** Build the dense mesh as now (colours, folds, curvature), decimate a copy to budget, and bake the dense mesh's paint onto the low mesh with Cycles "selected to active". This keeps the painted detail at a fraction of the triangles.

## Target budget (~35k per kid)

| Part | Now (approx.) | Target |
|---|---|---|
| Head (loft) | ~19k | 3–4k (rings ~44 × segments ~48, face-crowded) |
| Ears | ~1k | 0.5k |
| Hair | 24k (Leo) / ~30k (Nela) | 8–10k |
| Skin body, shirt, shorts or pants | ~45k | 12–15k |
| Hands and boots | ~8k | 3k |
| Gear (pack, stick, lantern, bunny, compass) | ~20k | 6–8k |

## Implementation
1. **`art/lib/paint_bake.py`: add a `high=` option to `paint(obj, ..., high=None, cage_extrusion=0.01)`.**
   - With `high` set, the build material (the attribute or FaceUV source) goes on the high mesh.
   - The low mesh gets PaintUV and the target image.
   - The bake runs with `use_selected_to_active=True` and a small extrusion or max ray distance.
   - Lighting, AO, cavity and curvature evaluate on the high mesh, so the folds' painted shading transfers.
   - The high mesh is deleted afterwards.
   - The existing behaviour stays the default, so the imp and props are unchanged.
2. **`art/characters/chibi.py`: add a `lowpoly(obj, target_tris)` helper.**
   - It duplicates the mesh and decimates the copy: collapse, planar-aware, with symmetry where possible.
   - It transfers skin weights by rebinding with the same armature.
   - It returns `(low, high)`.
   - Reuse `common.decimate` / `chibi.decimate_tris`.
3. **`art/characters/head_loft.py`: a lower default density.**
   - `rings`/`segments` become about 44/48, keeping the face-band crowding.
   - The face is painted via FaceUV onto the low head, so the eyes and lips are unaffected.
   - If the nose wedge folds at that density, loft dense and use `lowpoly()` instead.
4. **`leo.py`, `nela.py`: route each part through `lowpoly` + `paint(high=...)` to the budgets above.**
   - Drop the "undecimated for crisp stripes" workarounds, which the bake now handles.
   - Update `chibi.report` targets.
5. **Outline check.** Confirm the inverted hull still looks clean on the coarser silhouette. Thicker hulls reveal facets less than thin ones; the hero thickness 0.013 is fine.
6. **Docs.**
   - `art/README.md`: the hero kids' budget becomes ≤40k, and describe the high-to-low bake.
   - `.features/015-game-budget/{plan,status}.md`.

## Verification
- `SCULPT=1` clay front, 3/4 and side views, and silhouettes of low against high: the silhouette must be unchanged at game size (120 px).
- A 512 draft bake (`BAKE_SIZE=512 DRAFT_EXPORT=1`) of both kids.
  - Check it in the Godot face-review scene and a `draft_day` screenshot.
  - The stripes, folds and face paint must match the current look.
  - Then discard the draft outputs (`git checkout` the GLBs, delete `*_paint.webp`, `.import` and `game/tools/_review`).
- Then the pending ship steps:
  - the final 2K bake and Godot reimport;
  - `render_icons`;
  - recheck the HP bar heights;
  - `tools/check.sh`;
  - `tools/export_playtest.sh`, reporting the zip sizes against the 30 MiB guideline and the triangle totals before and after;
  - commit and push to `ccr-10877e76-2578j9`.
