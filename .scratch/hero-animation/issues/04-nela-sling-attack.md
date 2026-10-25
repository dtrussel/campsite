# 04: Nela's sling attack

Status: done
Blocked by: 03

**What to build:** Nela's own attack clip, which replaces `Spellcast_Shoot`. She loads the pouch, pulls the sling back, and lets go on the contact frame, which is when the pebble flies, with a light follow-through. Her personality is careful and precise, unlike Leo's eager swing.

- [x] Nela's `attack` maps to her new clip. The stock clip stays as a fallback.
- [x] Validate: her contact time matches the script's and is within the wind-up cap. Her attack checks are enforced.
- [x] Smoke from 02 still passes for Nela in both roles, and with the Double Sling's second pebble.
- [x] The contact sheet, GIF and old-and-new in-game captures are under `## Comments` for sign-off.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-25, done (open: the user's sign-off on the motion, from the captures below).** `hero_clips.py` has Nela's own clip, `Nela_Attack`, and her builder now calls `add_clips` and `write_record` (as Leo's does), so `game/assets/custom/nela_clips.json` records it. `Spellcast_Shoot` stays in the model as the fallback.
  - **Her slingshot shot (`Nela_Attack`, 22 frames at 24 fps = the spell cast's 0.917 s, 0.611 s at 1.5x):** her lantern stays in her right hand, so the fork is held in the same fist (the lantern hangs below it) and she draws the pouch with her left. Drawn at frame 0 (fork arm straight out at the target, the pouch pulled back beside her jaw, chest turned so the fork shoulder leads, weight on the back foot, head down along the aim); contact at frame 3 (0.125 s: 0.083 s played, 0.086 s as the companion, under the 0.1 s cap), where she lets go and the empty draw hand flicks back and up; follow-through at 6 (draw hand opens out to the side, the fork arm holds the aim); she watches the shot at 10; reload at 15 (the draw hand dips to her hip pouch, the fork arm comes down); Idle at 22. Careful and still where Leo's swing is bouncy: her Style (bounce 0.8) keeps the hips' dips small, and the fork arm barely moves through the shot. Both arms were solved offline for target hand positions (and the lantern hanging down from the fork hand); the rest is hand-set.
  - There is no sling mesh: the kids carry no tool prop for the sling, so the shot is mimed. A sling prop on `handslot.l` would be its own art ticket.
  - `nela.tres`: `attack` -> `Nela_Attack`, `attack_contact_time` 0.125 (was the 0.14 stand-in). `ClipChecks.ENFORCED` now has `nela attack: duration` (0.611 s against 0.611 s). Setting 0.14 back makes the validator fail on the clip record, as for Leo.
  - Nela is 35,711 tris (budget 40k). `tools/check.sh`: validate OK, unit PASSED (70), smoke PASSED in both passes (hero_animation covers Nela in both roles; tool_tiers fires the Double Sling's second pebble).
  - **For sign-off** (in `../captures/`): `04-nela-attack-clay-34.png/.gif` and `04-nela-attack-clay-side.png/.gif` (clay, game camera; the "side" one is turned -60 deg so her draw hand shows), and `04-nela-attack-player-old-vs-new.png` and `04-nela-attack-companion-old-vs-new.png` (in game, old on top, captured before the rebuild). As with Leo, the in-game strips begin mid-fade from Idle, so the draw shows best in the clay GIFs.
