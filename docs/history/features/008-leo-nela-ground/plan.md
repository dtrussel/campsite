# Feature 008: Painted ground, and Leo and Nela from the concept art

## Context
The user asked for two things after v0.3.0-playtest1:
1. **Hand-painted ground textures** (a deferred item from feature 007).
2. **Rebuilt main characters from their concept art.** The boy is **Leo**:
   - messy blond hair, a backwards navy cap, a light-blue tee, teal striped shorts;
   - hiking boots, a camo backpack with a bedroll, bottle and rope;
   - a compass and a walking stick.

   The girl is **Nela**, the younger sister:
   - wild blond hair, a light-blue tee, plum folk-pattern harem pants;
   - brown boots with pink laces;
   - a plum backpack with a bunny plush, and a glowing lantern.

   Use their names in the game.

## Already done (uncommitted, in the working tree)
**Ground**
- `art/ground/textures.py` paints 3 seamlessly tiling 1024 px textures with numpy brush stamps:
  - `game/assets/custom/ground_{grass,dirt,leaves}.png`;
  - a hand-written `.import` file for each (lossless, with mipmaps).
- `game/shaders/painted_ground.gdshader` was rewritten:
  - it samples the textures with anti-tiling (two rotated samples blended by macro noise);
  - it keeps the dirt clearing around the campfire, now with a scorched ring;
  - leaf litter and a cool tint take over toward the haunted forest edge.
- The textures live in a shared `game/assets/materials/painted_ground.tres`, used by:
  - `scenes/world/TestWorld.tscn`, which now references the `.tres`;
  - `scripts/ui/title_backdrop.gd`, through `GROUND_MATERIAL`.
- `check.sh` passes, and the screenshots were reviewed.

**Characters**
- `art/characters/chibi.py` is a new shared kit. It works on the KayKit rig, which is identical in Rogue and Mage (same 76 clips):
  - clothing pieces are fused primitives that are voxel-remeshed and auto-weighted;
  - accessories are rigid parts bound to one bone;
  - `HeadFrame` provides single-sided face decals: eyes with iris, pupil and highlights, lashes, brows, smile, freckles;
  - also: wavy and curved hair locks, boots, hands, compass, bedroll, rope coil, straps;
  - `QUICK=1` renders a fast preview with no bake.
- `art/characters/leo.py` writes `leo.glb` (about 28k tris). Its objects are `Leo`, `Leo_Head` and `Leo_Stick`.
- `art/characters/nela.py` writes `nela.glb` (about 36k tris). Its objects are `Nela`, `Nela_Head`, `Nela_Lantern` and `Nela_LanternGlow` (emissive).
- Both are fully baked. The head gets softer AO, and the previews were reviewed (T-pose, idle, run, attack, back, face).

## Remaining steps
1. **Swap the models in.**
   - `scenes/player/PlayerBoy.tscn` → `custom/leo.glb`, scale 0.72.
   - `scenes/companions/Sibling.tscn` → `custom/nela.glb`, scale 0.62. The clip maps stay the same: same rig and clip names.
   - Add a small warm `OmniLight3D` to Sibling (lantern glow, range about 3, energy about 0.6).
2. **Portraits.** In `tools/render_icons.gd`, render `portrait_leo` and `portrait_nela`, hiding `Leo_Stick` / `Nela_Lantern` / `Nela_LanternGlow`. Update the icon references in:
   - `hud.gd` (the `portrait_boy` / `portrait_sibling` references);
   - `end_screen.gd`;
   - `ui_kit.gd` `PICTURE_GUIDE`.

   Then re-run `tools/render_icons.tscn` and delete the old portrait PNGs.
3. **Names (minimal text).**
   - `resources/companions/sibling.tres`: `display_name = "Nela"`.
   - `ui_kit.gd` CONTROLS: "Nela: Follow / …".
   - `PICTURE_GUIDE`: "Helper" → "Nela".
   - A small name tag ("Leo", "Nela") under each HUD portrait in `hud.gd`.
   - The title backdrop uses the new glbs.
4. **Clean up.**
   - Delete `art/characters/{boy,sibling,kid_lib}.py`.
   - Delete `game/assets/custom/{boy,sibling}*` (glb, png, .import).
   - Grep for any remaining references.
   - Add `ground` to `tools/build_art.sh` (it runs `ground/textures.py`).
5. **Verify.**
   - `tools/check.sh`: import, validator and smoke run.
   - Xvfb screenshots via `tests/sim/screenshots.tscn`: title, day HUD, night. Check scale, outline, lantern and ground. Fix anything that is off: model scale, HP bar heights, hair clipping.
6. **Docs.**
   - `art/README.md`: add chibi/leo/nela/ground.
   - `CREDITS.md`: kids and ground are original; the rig and animations remain KayKit.
   - `README.md` and `docs/testing/PLAYTEST-README.txt`: name Leo and Nela.
   - `.features/008-leo-nela-ground/{plan,status,decisions,test-plan,handoff}.md`.
   - Bump to `0.4.0-playtest1`.
7. **Ship.**
   - Commit and push to `claude/game-assessment-testing-plan-uv9mw2`.
   - Run `tools/export_playtest.sh`. Check that part 1 of the split zip stays under 30 MiB; the new glbs are about 14 MB together.
   - Send the zips and the preview sheet plus in-game screenshots to the user.

## Verification
- `tools/check.sh` is green.
- The Blender preview sheets (`sheet_leo.png`, `sheet_nela.png`) show clean skinning in idle, run and attack.
- In-game screenshots show Leo with the stick, Nela with the lantern, painted ground, and correct HUD portraits and names.
- The export self-test passes.
