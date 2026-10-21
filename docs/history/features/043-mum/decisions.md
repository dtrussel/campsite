# Feature 043: Decisions

- **Portraits from the sheet, not 3D renders.** Mum speaks only in the painted storybook, and the sheet's painted heads match the paintings.
- **One `face` key per line**, falling back to `mum.png`. The other speakers keep a single portrait for now.
- **Same rig as the kids.** All their clips work and the pipeline stays the same. Adult build comes from `Proportions`; the head is built at kid scale (the face kit's numbers fit) and then scaled by `HEAD_SCALE`.
- **Wave is hand-keyed** with `rig_anims`, because the Rogue rig has no wave. The stock clips are kept, unlike for the creatures.
- **The beagle is not adopted** (decided with the user): concept flavour only.
- **Mum appears in 3D only after the true ending.** The story has her missing until then, so she isn't on the title screen or in runs before it.
- **Proportions follow the sheet, by measurement.** The sheet is a stylized build of about 5.8 heads, so the model matches its landmarks in fractions of height rather than realistic anatomy. `MEASURE=1` is the check to rerun after any body change.
- **`Proportions(shins=)` is optional** and defaults to the old uniform leg stretch, so Leo and Nela are unchanged.
- **Her arrival is relative to the played hero**, not a fixed spot, so the paused camera always sees it.
