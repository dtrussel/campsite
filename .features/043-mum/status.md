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
- **Checks.** `tools/check.sh` passes: validate OK and smoke PASSED. The smoke test covers the portraits with their fallback, the model and its Wave and walk clips, the walk while paused, the skip, and the title seat.
