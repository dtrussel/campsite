# Feature 008: Status

## 2026-09-28

**Completed**
- **Hand-painted ground:**
  - `art/ground/textures.py` paints seamless grass, dirt and leaf-litter textures;
  - `painted_ground.gdshader` samples them with anti-tiling, around the campfire clearing and toward the haunted leaf-litter edge;
  - one shared material (`assets/materials/painted_ground.tres`) is used by the world and the title screen.
- **Leo** (the player), modelled from the concept art (`art/characters/leo.py`, `leo.glb`):
  - backwards cap, messy blond hair, big blue eyes, freckles and a grin;
  - tee with a badge, striped board shorts, hiking boots;
  - camo backpack with a bedroll, bottle and rope; a compass; a walking stick (his weapon).
- **Nela** (the helper, `art/characters/nela.py`, `nela.glb`):
  - wild wavy hair with a top ponytail, big eyes, an open laugh;
  - plum folk-pattern harem pants, pink-laced boots;
  - plum backpack with a bunny plush, bedroll and cup; a compass;
  - a glowing lantern, plus a warm light in her scene.
- **Names:** Leo and Nela appear under the HUD portraits, in the help picture guide and the controls list, and in the companion definition.
- **Removed:** the old KayKit-based boy and sibling (the scripts, the `.glb` files and the portraits).
- **Checks:** `tools/check.sh` is green, and the screenshots were reviewed.

**Known limits**
- The characters are about 28k and 36k triangles. That is fine on desktop; decimate the hair locks if a low-end PC struggles.
- Nela still "attacks" with the spellcast animation, now read as a lantern flash.
