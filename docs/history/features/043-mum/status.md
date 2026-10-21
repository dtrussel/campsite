# Feature 043: Status

**Done.**

- **Reference.** The sheet is stored as `14_mum_character_sheet.webp` and listed in the concept README as canonical for Mum.
- **Portraits.** Six round, brass-ringed 192 px busts: smile (the default), curious, laugh, surprised, worried and proud.
  - "Stay here. Keep the fire burning..." uses `worried`.
  - "My brave ones..." uses `laugh`.
  - The validator checks that every face exists and is only used on Mum's lines.
- **3D model.** `mum.glb` is 35.5k triangles: body 21k, head 4.5k, hair 10k.
  - Proportions: legs 3.1, spine 1.3, arms 1.5. The head is scaled by 0.74.
  - The look follows the sheet: lime jacket with rolled sleeves over a black top, mountain badge, chest pockets, belt, tan scarf, charcoal cargo trousers, brown boots with red laces, olive pack with blue bedroll, tin mug on a red carabiner, brass compass, and long wavy blond hair in a low bun.
  - Clips: all the stock clips, plus `Wave`.
  - In the game she is 0.72 scale, against Leo's 0.7 and Nela's 0.65.
- **True ending.** After the last night of Chapter 2, Mum walks in from the treeline to the kids and waves, and the kids turn and cheer. Then the ending book opens. It runs while the world is paused, and a click, Space or Enter skips it.
- **Title.** After the true ending, Mum sits by the title fire with Leo and Nela.
- **Second pass (by request), against the sheet:**
  - **Face:** rounder cheeks, bigger eyes glancing aside, stronger brows, a fuller blush, and a big warm smile showing teeth.
  - **Hair:** a much fuller head of hair. It sweeps back over a rounded crown into a bigger loose low bun; side-swept bangs drape over the forehead; layered wavy locks fall round the sides and back to the shoulders, with face-framing locks; there are fewer spiky flyaways.
  - **Clothes:** the jacket is a brighter chartreuse, open wider over the black top, with zip edges, a turned-down collar and the sleeves rolled to just below the elbow. The scarf is bigger and lighter, with a front loop and tails. The trousers are browner and tucked into chunkier boots, and the cargo pockets have snaps and sit on the thighs.
  - **Fixes:**
    - Her hidden leg skin poked through the trousers when she sat; the legs are removed.
    - The exporter reported "Mesh Mum is not valid". The meshes are now repaired before export.
  - **Tooling:** `HEAD_ONLY=1` previews just the face and hair in about 20 s. `EXTRA_CLIPS=a,b` adds clip previews.
- **Third pass: body proportions, measured (by request).**
  - **Research first.** The method that works for an agent building a character from code is a closed, measured loop: render from the reference's view, compare in numbers (landmarks in head units, silhouette overlays), edit, repeat. Adult female drawing proportions are about 7–7.5 heads tall with shoulders and hips around 2 heads wide, but the sheet is a stylized build of about **5.8 heads**, so the sheet is the target, not anatomy.
  - **Measured.** The sheet's front turnaround gives landmarks as fractions of height: head 0.173, chin 0.827, shoulders 0.755, belt 0.54, crotch 0.474, knees 0.27, shoulder width 0.255, hip width 0.216, thigh 0.10.
  - **The previous model** measured head 0.136 (7.3 heads), shoulders 0.20 and hips 0.17 wide, thighs 0.076, and a long torso. She was too tall, thin and small-headed: a realistic adult, not the sheet's sturdy stylized one.
  - **Now:**
    - every landmark is within about 0.02 of the sheet;
    - the head is bigger (`HEAD_SCALE` 0.9) and the torso shorter (spine 0.92);
    - shoulders, chest, hips and thighs are wider, the waist is narrower, and the legs taper in a slight A stance;
    - the shins are longer than the thighs (the new `Proportions(shins=)`), so the knees sit where the sheet has them;
    - the hair falls closer to the shoulders, the scarf wraps high up the neck as drawn, and the pack is bigger and lower.
  - **Tools:** `art/lib/measure.py`, and `MEASURE=1` on `mum.py` prints the table and renders front and side silhouettes.
- **Checks.** `tools/check.sh` passes: validate OK and smoke PASSED. The smoke test covers the portraits with their fallback, the model and its Wave and walk clips, the walk while paused, the skip, and the title seat.
