# Credits

## Art

**Original art.** The boy, sibling and Shadow Imp models, trees, pines,
rocks, berry bushes and camp props (campfire, tent, fence, watch post,
torch, woodpile, crate, barrel, toadstools) are original to this project.
They are generated and hand-paint-baked by the Blender scripts in `art/`
(`tools/build_art.sh`) and written to `game/assets/custom/`.

**KayKit.** The characters still use KayKit skeletons and animations:
the kids are reshaped and repainted KayKit adventurers, and the imp is a
new body on the Skeleton Minion rig. Hills, mountains, dead trees,
pumpkins and lanterns are KayKit models.

3D models and animations by **Kay Lousberg** — [KayKit](https://kaylousberg.com),
released under **CC0 1.0** (public domain; no attribution required, credited
with thanks). Vendored by `tools/fetch_assets.sh` from pinned commits of:

| Pack | Used for |
|------|----------|
| [KayKit Character Pack: Adventurers 1.0](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0) | Base meshes, rigs and animations for the boy (Rogue) and sibling (Mage) |
| [KayKit Character Pack: Skeletons 1.0](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0) | Rig and animations for the Shadow Imp (Skeleton Minion) |
| [KayKit Halloween Bits 1.0](https://github.com/KayKit-Game-Assets/KayKit-Halloween-Bits-1.0) | Autumn pines, dead trees, pumpkins, lanterns, candles |
| [KayKit Medieval Hexagon Pack 1.0](https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0) | Hills and far background |

Each pack's `LICENSE.txt` is kept next to its files in `game/assets/kaykit/`.

## Fonts

- **Cinzel** by Natanael Gama — SIL Open Font License 1.1
- **Nunito Sans** by Vernon Adams, Jacques Le Bailly et al. — SIL Open Font License 1.1

License texts: `game/assets/fonts/*-OFL.txt`.

## Everything else

Shaders (ground, grass, flames, health bars, hover rim), particle effects,
UI widgets, rendered icons and all code are original to this project.
