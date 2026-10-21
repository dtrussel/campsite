# Feature 007 — Test plan

1. `tools/check.sh`: import, the validator (loads every scene and custom
   `.glb`), and a full smoke run.
2. Xvfb screenshots (`tests/sim/screenshots.tscn`) of title, help, day
   HUD, crafting, build ghost, sunset, night wave, night later, pause
   and end screen. Check:
   - models read clearly from the game camera;
   - the outline is visible on the kids and imps;
   - there is no overlapping UI;
   - no screen needs reading to understand it.
3. **Blender previews** of each asset, and animated frames of the
   characters (walk, run, chop, spellcast, punch, awaken), to confirm
   clean skinning.
4. **Windows export:** `tools/export_playtest.sh` self-test, with zips
   split under the upload limit.
5. **Human playtest:** can a child start, fight, gather and build
   without reading? Note any screen where they ask "what does this
   say?".
