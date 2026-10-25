# 03: Hero clip script, plus Leo's stick swing

Status: ready-for-agent
Blocked by: 01, 02

**What to build:** the tracer for hand-made hero clips. A Blender Python script, built on the shared clip helpers the mobs use, keys clips on the kids' KayKit rig and exports them inside the kid's model. Its first clip is Leo's own stick swing: a short wind-up (anticipation), the strike on the contact frame, and a follow-through with overlap that suits a chibi kid. Leo's clip mapping points `attack` at it. The script prints the clip's contact time, which goes onto Leo's data.

- [ ] The script can key a clip for either kid and add it to that kid's model export. Style knobs (bounce, arm swing, posture) are accepted per kid, ready for the shared clips.
- [ ] Leo's attack clip replaces `1H_Melee_Attack_Chop` for `attack`. The stock clip stays in the model as a fallback.
- [ ] Validate: Leo's contact time on his data matches the script's and is within the wind-up cap. Leo's attack checks (from 01) are switched to "enforce".
- [ ] Smoke from 02 still passes for Leo in both roles.
- [ ] The contact sheet and GIF of the new swing, and old-and-new in-game captures, are attached under `## Comments` for the user's sign-off.
- [ ] The kids stay within the hero triangle budget.
- [ ] `art/README.md` lists the hero clip script.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
