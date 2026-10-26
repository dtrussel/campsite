# 08: Work actions

Status: done (open: the user's visual sign-off)
Blocked by: 07 (the clip pipeline is from 03; 07 only orders the model rebuilds)

**What to build:** the camp work looks like a kid doing that job. These are shared clips, varied by the style knobs, for `gather`, `chop`, `pick`, `tinker` and `hammer`. The build and repair beat swings the barrel mallet in one hand, instead of a two-handed axe chop. Every clip keeps today's duration, so gathering and building take as long as before.

- [x] The five states map to the new clips for both kids. The stock clips stay as fallbacks.
- [x] Validate: each clip's length at its play speed matches the duration recorded in 01 (enforced).
- [x] The existing gather, build and repair smoke checks still pass unchanged.
- [x] Contact sheets, GIFs and in-game captures (chopping a tree, picking up, building with the mallet) are under `## Comments` for sign-off.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-26, done (open: the user's sign-off on the motion, from the captures below).** Shared `Hero_Chop`, `Hero_Pick`, `Hero_Gather`, `Hero_Hammer` and `Hero_Tinker`, keyed in `hero_clips.py` with `_posed` and each kid's `Style` (bounce scales the dips, arm swing the wind-ups), and rebuilt into both models; both kids' hero data map `chop`, `pick`, `gather`, `hammer` and `tinker` to them. The stock `1H_Melee_Attack_Chop`, `PickUp`, `Interact`, `2H_Melee_Attack_Chop` and `Use_Item` stay in the models as the fallback.
  - **Clips** (each at the stock length at its play speed: chop 25 frames, 0.69 s at 1.5x; pick 31 frames, 0.86 s at 1.5x and 0.81 s at the build fetch's 1.6x, as before; gather 31 frames, 0.99 s at 1.3x; tinker 38 frames, 0.99 s at 1.6x; hammer 39 frames, 0.90 s at 1.8x). Chop: a twist back with the hand out to the side, a forehand whack across into the trunk at waist height, a jolt off it and a shake of the stung hand; Leo's stick lands flat on the trunk, Nela's lantern hangs (she whacks with her lantern hand, as her other clips keep the lantern hanging). Pick: a squat, the free left hand to the ground (it gets within about 0.18 m of the ground target; the kids' big heads stop a deeper fold), a look at the find, a pat into the pocket; the right hand rests on the knee with Leo's stick laid out behind, clear of the ground. Gather: a lean in with both hands, two tugs, a hug of the haul. Hammer: the left hand steadies the plank, the right swings the barrel mallet one-handed up over the shoulder and down, landing on frame 20 of 39 (0.513, `BuildBeat.IMPACT_AT` is 0.52, unchanged), a bounce off the wood and a settle. Tinker: bent to a peg, the left hand wiggles it in with the head tipping, then two light mallet taps.
  - **How:** a new `Key.grip` sets the hand slot's whole turn (the mallet's handle runs along the slot's +Y, its barrel faces along +X; `_mallet(lift)` cocks it back from striking flat down), and a clip with grips slerps the whole slot turn key to key. `clip_sheet.py` now holds the mallet for `hammer` and `tinker` (and hides the kid's prop, as the game does), and `hero_capture` shows the mallet for `tinker` too.
  - **Checks:** the validator enforces `duration` for all five states for both kids (all within 0.002 s of the stock lengths). The existing gather, build and repair smoke checks pass unchanged. `tools/check.sh`: validate OK, unit PASSED, smoke PASSED in both passes, selftest OK. Leo 34,999 tris, Nela 35,711 (unchanged).
  - **For sign-off** (in `../captures/`): clay strips `08-<kid>-<state>-clay.png` for all five, clay GIFs `08-<kid>-hammer-clay.gif`; in game `08-<kid>-<state>-player-old-vs-new.png` (old on top, captured before the rebuild) for all five, and `08-<kid>-<chop|pick|hammer>-player-new.gif` (chopping, picking up, building with the mallet). The in-game captures show the kid alone, not the tree or the building.
