# Feature 006 — Decisions

## D-006-1 — CC0 KayKit art, vendored and pinned
The KayKit packs on GitHub are CC0. That means no licence risk and no
attribution requirement (we credit them anyway in `CREDITS.md`). They
are consistent in style, and the characters come with 75+ animations.

We commit only the files we use, fetched from pinned commits, so builds
never need network access. Alternatives were not reachable from the
build environment: itch.io, Kenney, Quaternius and Poly Haven are
blocked by the network policy.

## D-006-2 — Night mobs are recoloured skeleton minions
None of the packs has a "shadow imp". The user chose the Skeleton
Minion with a `shadow` style profile:
- dark violet body with rim glow;
- burning eyes;
- rises from the ground on spawn and collapses into purple smoke on
  death.

## D-006-3 — LoL-style right-click control
This was the user's choice.

**The pointer issues commands; the player controller carries them out.**
- `PointerCommands` issues move, attack, gather and campfire commands.
- `PlayerController` carries them out using a runtime-baked navmesh.
- The navmesh is re-baked whenever buildings change.

**Keyboard shortcuts are kept:**
- Space attacks the nearest imp, and E gathers the nearest resource.
- WASD still works as a direct override.

**Mouse buttons:**
- A left click on a target acts on it but never moves the boy.
- In build mode, BuildManager owns the mouse (left click places, right
  click cancels).

## D-006-4 — Styling at runtime, not by editing the imported models
The `Stylize` helper duplicates each imported material once per
profile and tint, and caches the result:
- all materials: matte finish plus rim light;
- per-model tints for KayKit's teal foliage and white rocks.

`StyleDirector` applies the default profile to every mesh in the scene,
including meshes spawned later. Characters then override it with their
own profile.

Re-importing or updating a pack therefore never loses the look.

## D-006-5 — The UI is drawn in code
The HUD widgets (bars, portraits, ability slots and day clock) are
drawn with `Control._draw`, styled by one `UiKit` theme:
- Cinzel for titles, Nunito Sans for body text;
- navy panels with gold trim.

The only image assets are icons rendered from our own 3D models.

**Theme gotcha:** the theme has to be set on each UI root. Theme
inheritance stops at CanvasLayer, so setting it on the root window is
not enough.

## D-006-6 — Known rendering gotchas
- Billboard particle materials need `billboard_keep_scale`; without it
  every sprite rendered 1 m wide.
- Grass has to flip its normal on back faces.
- The navmesh surface sits about 0.5 m above the ground, so the
  NavigationAgent needs `path_height_offset`.
