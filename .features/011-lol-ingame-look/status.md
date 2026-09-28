# Feature 011: Status

## 2026-09-28

**Completed**
- **Painted faces (the LoL way).** `art/characters/face_paint.py` paints the eyes, brows, nose and lip shading, contours, blush, freckles and face paint into a front-projected overlay. `paint_bake` blends it in under the baked lighting (`overlay`, `FaceUV`). The old decal eyes and mouths are gone.
- **Sculpted relief.** `chibi.sculpt_features` carves eye sockets, a slight eyeball, the brow ridge, nose (bridge, tip, wings), lips, philtrum, chin and cheekbones. It uses the same `FaceLayout`, so the paint lines up with the geometry.
- **Separate textures.** Head skin and hair are baked to separate textures, so the face gets most of the texels.
- **Stronger painted bake.** A baked key light (`key_light`), cavity darkening (`cavity`), stronger AO and darkening toward the feet. The palettes are earthier.
- **Proportions in between.**
  - Leo's head is about 1/5 of his height: legs 1.85, spine 1.3, arms 1.25.
  - Nela's head is about 1/3.5: legs 1.3, spine 1.1, arms 1.1.
  - `reference_speed` was raised for the longer strides.
- **Leo (Ekko).** Heavy-lidded eyes, a cocked brushed brow, a firm smirk, teal cheek marks, a broader jaw, fingerless gloves, shin wraps and baggier shorts.
- **Nela (Annie).** Big sly eyes with smoky pink-violet shadow and a winged liner, brows angled in, small rosy lips, a strong blush, a solid blunt fringe, capri pants with striped leg warmers, and a bunny with a button eye and a patch.
- **Review.** Side-by-side comparison sheets against the reference screenshots were reviewed at each step. `tools/check.sh` is green.
