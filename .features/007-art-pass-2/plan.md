# Feature 007 — Art pass 2: LoL-style models and a kid-friendly UI

## Context
The KayKit art pass (feature 006) was a big step up, but the user still finds the models "too basic". KayKit uses flat gradient colours, low-poly faceted shapes and generic adventurers. The user wants a look closer to League of Legends:
- hand-painted textures;
- chunky, appealing silhouettes;
- expressive characters.

They also point out that the audience is **children**, so UI text must be minimal and icons must carry the meaning.

**New capability found:** Blender runs here headless as a Python module. `bpy` 4.5 has a manylinux cp311 wheel on PyPI, which is reachable. The machine has 4 CPUs and 15 GB RAM, and no GPU is needed for Cycles CPU baking. That gives us, all scriptable:
- real modelling and subdivision;
- remeshing;
- texture baking;
- automatic rigging;
- glTF export.

**User decisions:**
- **Characters:** a brand-new modelled Shadow Imp (driven by the skeleton rig, so its animations still work), plus upgraded kids (KayKit bodies with smoother shapes, painted textures, kid gear).
- **Style:** LoL-style painted textures and soft lighting, plus a thin outline on characters and enemies for readability.

## Approach

### 0. Blender toolchain (reproducible, not needed to run the game)
- `tools/setup_blender.sh` installs `bpy==4.5.x` into a venv at `.venv-blender/`, which is git-ignored.
- `art/` holds the procedural Blender scripts (the art source, committed):
  - `art/lib/` shared helpers: painted-texture baking, UV unwrapping, glTF export, rig helpers.
  - `art/characters/`, `art/props/`, `art/nature/` hold one script per asset.
- `tools/build_art.sh [asset…]` runs each script and writes a `.glb` to `game/assets/custom/<asset>.glb`. The outputs are committed so the game never needs Blender.
- Turntable previews: each build also renders a small EEVEE/Cycles preview PNG to the scratchpad for review.

### 1. The "painted look" pipeline (`art/lib/paint_bake.py`), used by every asset
For each mesh:
1. Auto-UV the mesh (smart project, then pack).
2. Build a bake material that combines:
   - base palette colours (per face, or the colour region from the source atlas);
   - a warm top light and cool underside (a gradient from the normal's Z);
   - baked ambient occlusion (darkens crevices);
   - edge highlights from the Geometry "pointiness"/Bevel normal difference;
   - brush-stroke noise and hue jitter.
3. Bake all of that to one 512–1024 px diffuse texture with Cycles CPU.
4. Export with an unlit-friendly material, which Godot restyles.

This is what gives the LoL "lighting painted into the texture" look.

### 2. Characters
- **Shadow Imp (new model):** built on the vendored `Skeleton_Minion.glb` armature.
  - **Body:** generated from the rig itself. Metaball capsules run along every bone, with a radius per bone: fat belly, big round head, stubby limbs. It is voxel-remeshed and decimated to about 4–6k triangles, so it fits the rig exactly.
  - **Added parts:** curved horns, pointy ears, big glowing eyes (a separate emissive material), bat wings and a spade tail. Each part is rigidly weighted to the head, chest or hips bone.
  - **Rigging:** automatic weights; the old skeleton meshes are deleted.
  - **Texture:** painted deep violet with a lighter belly and magenta rim areas. Cute-spooky, not scary.
  - **Animations:** all skeleton clips are kept (awaken from the ground, walk, attack, hit, collapse).
- **Boy:** built on `Rogue.glb`.
  - One level of subdivision with smooth shading; skin weights are kept.
  - Bigger head (for kid proportions) and spiky hair tufts.
  - A green hooded scarf, a small backpack, and a bigger cartoon axe.
  - Painted bake of the body: warm skin, orange hair, green tunic.
- **Sibling:** built on `Mage.glb`.
  - Subdivided, with a bigger floppy starry wizard hat (a painted star pattern).
  - A short cape and a wand with a glowing star tip.
  - Painted bake.
- `CharacterVisual` scenes point at the new `.glb` files. The `clips` mapping stays the same, because the animation names are preserved.

### 3. Props and nature (new procedural models, painted bake)
**Nature**
- **Broadleaf trees** (3 variants plus a stump):
  - a twisted chunky trunk with flared roots (skin modifier on a branch graph);
  - a lumpy clustered canopy (merged icospheres, voxel remesh, displacement);
  - dark underside, sunlit top, leaf-noise texture.
- **Autumn pines** (2 variants): drooping stacked tiers in orange and red.
- **Rocks** (3 variants): displaced, beveled, with moss on top from a normal-up mask.
- **Berry bush** (full and picked): lumpy foliage with glossy berries.

**Camp props**
- **Campfire:** chunky stone ring, crossed logs, ember bed.
- **Tent:** a kid's striped A-frame tent with an open flap, pegs and ropes.
- **Wooden fence:** pointed stakes with rope bindings.
- **Watch post:** a small lookout with a roof and a ladder.
- **Torch:** a stick torch with wrapped cloth and a flame cup.
- **Dressing:** woodpile, crate, barrel, sack, mushrooms, flower clumps.

**Backdrop:** KayKit hills and mountains stay as far background, restyled by the shader, plus custom tree clusters.

Scenes swap to the new models:
- `scenes/resources/{TreeNode,PineTree,RockNode,BerryBush}.tscn`;
- `scenes/buildings/{WoodenFence,WatchPost,Torch}.tscn`;
- `scenes/base/CampfireCore.tscn`;
- `scripts/world/world_dressing.gd` (model list).

### 4. Rendering in Godot
- `shaders/painted.gdshader` for the custom assets:
  - painted albedo;
  - soft two-band lighting (wrap/half-Lambert ramp) that keeps the painted shading readable;
  - rim light, with night-friendly ambient.
- `shaders/outline.gdshader`: an inverted-hull `next_pass`, used for characters and mobs. It is thin, dark tinted, and its thickness is scaled by distance.
- `Stylize` gains the profiles `painted`, `painted_hero` (with outline) and `painted_shadow`. Materials are cached per profile as they are today.
- Ground: bake tileable hand-painted grass and dirt textures in Blender and sample them in `painted_ground.gdshader` with world UVs plus the existing macro variation.

### 5. Kid-friendly UI: icons over text
- **Top centre:** a sun/moon clock and **3 moon icons** that light up per night survived, plus a fire icon on the campfire bar. No "Nights survived …" text and no timer digits.
- **Banners:** a big icon with 1–2 words ("NIGHT!", "DAWN!", "LEVEL UP!").
- **Sibling frame:** 4 clickable **task icons** (footsteps, shield, basket, zzz). The active one glows. No text.
- **Help overlay:** pictograms (mouse-button icon → footsteps, sword on imp, axe on tree), with at most 3 words each.
- **Other screens:**
  - title: a big ▶ Play;
  - end screen: a trophy or broken campfire, 3 stars, and icon + number stats;
  - crafting panel: input icons → output icon and a ✔ button.
- **Hints:** "No torch…" and similar become icon pop-ups (item icon with a red ✕).
- **Floating text:** numbers only; XP becomes a sparkle.
- **Glyph icons:** drawn in code (`HudWidgets` vector glyphs) or rendered in Blender, stored in `game/assets/icons/`.

## Critical files
- **New:**
  - `tools/setup_blender.sh`, `tools/build_art.sh`;
  - `art/**` (Blender scripts);
  - `game/assets/custom/*.glb` and their textures;
  - `game/shaders/{painted,outline}.gdshader`;
  - `.features/007-art-pass-2/*`.
- **Modify:**
  - `scripts/utilities/{stylize,character_visual}.gd`;
  - character, resource, building and campfire scenes;
  - `world_dressing.gd`, `title_backdrop.gd`, `render_icons.gd`;
  - `hud.gd`, `hud_widgets.gd`, `ui_kit.gd` (CONTROLS become pictograms);
  - `controls_overlay.gd`, `end_screen.gd`, `crafting_panel.gd`;
  - `player_controller.gd` and `fx.gd` (icon pop-ups instead of text);
  - `CREDITS.md`.
- **Reuse:**
  - `CharacterVisual` (the clip map is unchanged);
  - `Stylize` and `StyleDirector`;
  - `Fx.burst` and `HealthBar3D`;
  - `tests/sim/screenshots.tscn`;
  - `tools/render_icons.tscn` (re-run for the new models);
  - `tools/check.sh`, `tools/export_playtest.sh`.

## Verification
1. **Per asset:** a Blender preview render, reviewed before import. Asset triangle budgets: characters ≤ 8k, trees ≤ 3k, props ≤ 1.5k.
2. **Imp rig:** each key clip (awaken, walk, punch, hit, collapse) is rendered at 3 frames in Blender to confirm the skin deforms cleanly.
3. `tools/check.sh` passes (validator loads every new `.glb`; smoke test covers the full win and loss runs).
4. **Godot screenshots** under Xvfb for title, day, crafting, build, sunset, night wave and end screen. Compare side by side with the previous build and send to the user.
5. `tools/export_playtest.sh`: self-test passes and the zip stays under the upload limit (split parts).
6. Commit per step and push to `claude/game-assessment-testing-plan-uv9mw2`.
