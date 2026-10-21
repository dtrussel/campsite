# Feature 009: Decisions

1. **Stretch the rig, not the animations.** A monotone piecewise remap of Z (feet, legs, torso, head shift) and X (arms) keeps vertical and horizontal bones' directions, so the local-rotation animations are unchanged. Hips translation keys are multiplied by the leg factor so crouches still meet the ground.
2. **Model in the original space, then remap.** All part coordinates stay readable. The head region above the neck is only shifted, so the faces are never distorted.
3. **Decals ray-cast onto the sculpted head.** Any head shape works with the same eye, mouth and brow code.
4. **Contrast by shape first, then palette.**
   - Leo: tall and lean, angular, a cap with a swept fringe, cool blues.
   - Nela: tiny, a round cloud of curls with a bun, a heart face, warm pinks and plum.
