# Feature 027: Decisions

- **Read from the game camera.** The camera looks down steeply, so the
  cap covers most of the body. In-game frames drove these changes:
  - the cap is a bit narrower than first built and tipped back 18°;
  - the ears are long enough to poke out past the rim;
  - the purple is darker (the house lighting pushed it to magenta);
  - `model_scale` went from 0.55 to 0.62.
- **Cheeky, not scary.** The grin curls up on one side with a single
  fang, the eyes are round amber with sly pupils, and the brows only
  tilt a little. The first grin baked as a jagged "stitched" line, so
  it is now painted with a soft edge.
- **Metaball sizing.** A lone ball's surface sits at about 0.58 of its
  radius (threshold 0.6, stiffness 2). The first draft came out
  spindly, with a floating pouch and strap, until the radii were scaled
  up (noted in the code).
- **Sneak vs flee.** Both move at the same speed (gameplay unchanged).
  The visual swaps the move clip, so sneaking in is a tiptoe and
  running off is a low scurry clutching the satchel. The grab plays on
  the upper body if it is already moving.
- **Shared keying helpers.** `rig_anims.py` holds the pose, mirror and
  key code for any Skeleton Minion creature. The imp could use it next.
