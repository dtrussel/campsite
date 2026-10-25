# 04: Nela's sling attack

Status: ready-for-agent
Blocked by: 03

**What to build:** Nela's own attack clip, which replaces `Spellcast_Shoot`. She loads the pouch, pulls the sling back, and lets go on the contact frame, which is when the pebble flies, with a light follow-through. Her personality is careful and precise, unlike Leo's eager swing.

- [ ] Nela's `attack` maps to her new clip. The stock clip stays as a fallback.
- [ ] Validate: her contact time matches the script's and is within the wind-up cap. Her attack checks are enforced.
- [ ] Smoke from 02 still passes for Nela in both roles, and with the Double Sling's second pebble.
- [ ] The contact sheet, GIF and old-and-new in-game captures are under `## Comments` for sign-off.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
