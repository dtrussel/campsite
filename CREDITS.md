# Credits

## Art

**Original art.** Leo, Nela (modelled from the project's own concept
art), the Shadow Imp, the Bramble Beast and the Mushroom Gremlin, the hand-painted ground textures, trees, pines,
rocks, berry bushes and camp props (campfire, tent, fence, watch post,
torch, woodpile, crate, barrel, toadstools, and the feature 017 clay
pit, mushroom patch, junk pile, snap trap, glow lantern, glow shard and
hearth ring, and the feature 019 reinforced wall, storage crate and
crafting table) are original to this project.
They are generated and hand-paint-baked by the Blender scripts in `art/`
(`tools/build_art.sh`) and written to `game/assets/custom/`.

Leo's and Nela's art style is inspired by League of Legends' young
champions (Ekko and Annie): proportions, silhouettes and face style.
The designs themselves are original, based on the project's own concept
art; no Riot Games assets are used.

**KayKit.** The characters still use KayKit skeletons and animations:
Leo and Nela are new models on the Adventurers rig, and the imp is a new
body on the Skeleton Minion rig, and so are the Bramble Beast and the
Mushroom Gremlin. Since 0.20 every prop and backdrop (hills, mountains,
dead trees, pumpkins, lanterns, the water bucket) is an original painted
model from `art/props/`; only the rigs, the animations and Leo's axe
come from KayKit.

3D models and animations by **Kay Lousberg** — [KayKit](https://kaylousberg.com),
released under **CC0 1.0** (public domain; no attribution required, credited
with thanks). Vendored by `tools/fetch_assets.sh` from pinned commits of:

| Pack | Used for |
|------|----------|
| [KayKit Character Pack: Adventurers 1.0](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0) | Rig and animations for Leo and Nela; the axe icon |
| [KayKit Character Pack: Skeletons 1.0](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0) | Rig for the Shadow Imp, Bramble Beast and Mushroom Gremlin (Skeleton Minion). All three mobs' clips are original (`art/characters/imp_anims.py`, `beast_anims.py`, `gremlin_anims.py`). |

Each pack's `LICENSE.txt` is kept next to its files in `game/assets/kaykit/`.

## Illustration

The key art on the boot splash and loading screen (Leo and Nela at
sunset with the camp and its monsters) was supplied by the project
team. It is kept at `art/ui/source/key_art.png`; `art/ui/key_art.py`
prepares the game versions and adds the logo.
The three monster paintings on the loading screens (the Shadow Imp on a
branch at night, the Bramble Beast at sunset, the Mushroom Gremlin by a
stream) were also supplied by the project team
(`art/ui/source/loading_*.png`).

## Audio

**Original sound.** All music, ambience and sound effects are
synthesized from scratch by the numpy scripts in `art/audio/`
(`tools/build_audio.sh`) and written to `game/assets/audio/`. No
recorded samples or third-party sounds are used.

## Fonts

- **Cinzel** by Natanael Gama — SIL Open Font License 1.1
- **Nunito Sans** by Vernon Adams, Jacques Le Bailly et al. — SIL Open Font License 1.1

License texts: `game/assets/fonts/*-OFL.txt`.

## Everything else

Shaders (ground, grass, painted foliage wind, flames, health bars, hover rim), particle effects (including the leaves, pollen and fireflies),
UI widgets, rendered icons and all code are original to this project.
