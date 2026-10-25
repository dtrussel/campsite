# 03: Hero clip script, plus Leo's stick swing

Status: done
Blocked by: 01, 02

**What to build:** the tracer for hand-made hero clips. A Blender Python script, built on the shared clip helpers the mobs use, keys clips on the kids' KayKit rig and exports them inside the kid's model. Its first clip is Leo's own stick swing: a short wind-up (anticipation), the strike on the contact frame, and a follow-through with overlap that suits a chibi kid. Leo's clip mapping points `attack` at it. The script prints the clip's contact time, which goes onto Leo's data.

- [x] The script can key a clip for either kid and add it to that kid's model export. Style knobs (bounce, arm swing, posture) are accepted per kid, ready for the shared clips.
- [x] Leo's attack clip replaces `1H_Melee_Attack_Chop` for `attack`. The stock clip stays in the model as a fallback.
- [x] Validate: Leo's contact time on his data matches the script's and is within the wind-up cap. Leo's attack checks (from 01) are switched to "enforce".
- [x] Smoke from 02 still passes for Leo in both roles.
- [x] The contact sheet and GIF of the new swing, and old-and-new in-game captures, are attached under `## Comments` for the user's sign-off.
- [x] The kids stay within the hero triangle budget.
- [x] `art/README.md` lists the hero clip script.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-25, done (open: the user's sign-off on the motion, from the captures below).** `art/characters/hero_clips.py` keys a kid's clips on the stretched adventurer rig next to the 76 stock clips (which stay, so `1H_Melee_Attack_Chop` is still in the model and still plays `chop`). It has a per-kid `Style` (bounce, arm swing, posture; Leo 1.25/1.15/+3 deg, Nela 0.8/0.85/-1 deg), each kid's own clips (`OWN`) and an empty `SHARED` set for tickets 05-08. `stock_pose` samples a stock clip (Idle) as a pose, so clips end exactly on Idle. Leo's builder calls `add_clips` and `write_record`, which saves each clip's length and contact time to `game/assets/custom/leo_clips.json`.
  - **Leo's swing (`Leo_Attack`, 25 frames at 24 fps = the chop's 1.042 s, 0.694 s at 1.5x):** wind-up with the stick cocked up and back over his right shoulder (frame 0), contact in front at a small mob's height with a knee dip (frame 3 = 0.125 s; 0.083 s played, 0.086 s as the companion, under the 0.1 s cap), follow-through low and across (6), overlap with the head and arm lagging and a small hop (10), settle (16), Idle (25). The stick arm's angles were solved offline for target hand positions and stick directions; the rest is hand-set.
  - `leo.tres`: `attack` -> `Leo_Attack`, `attack_contact_time` 0.125. The validator's new `_validate_hero_clip_records` fails when a hand-made attack clip's recorded contact time differs from the hero data (checked by setting 0.14: it fails). `ClipChecks.ENFORCED` now has `leo attack: duration` (0.694 s against 0.694 s).
  - Leo is 34,999 tris (budget 40k). `tools/check.sh`: validate OK, unit and smoke PASSED (the hero_animation scenario covers both roles).
  - `clip_sheet.py --rekey` keys the clips onto the committed model before rendering, so a clip can be reviewed in ~15 s without the bake.
  - **For sign-off** (in `../captures/`): `03-leo-attack-clay-34.png/.gif` and `03-leo-attack-clay-side.png/.gif` (clay, game camera, 3/4 and side), and `03-leo-attack-player-old-vs-new.png` and `03-leo-attack-companion-old-vs-new.png` (in game, old on top). The in-game strips start mid-fade from Idle, so the wind-up shows best in the clay GIFs.
  - The Blender export still warns "Mesh Leo is not valid" (it did before this change). Mum's builder fixes the same warning with `mesh.data.validate()`; Leo's doesn't yet.
