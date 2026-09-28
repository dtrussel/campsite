# Feature 007 — Decisions

1. **Procedural Blender art, committed outputs.** We run bpy headless and
   generate every model from a script. Assets can be rebuilt and tweaked
   in code review, and the game never depends on Blender.
2. **Keep the KayKit rigs.**
   - New or reshaped meshes are skinned to the existing skeletons, so
     all animations and `CharacterVisual` clip maps keep working.
   - The imp body is new: metaballs along its bones, then auto weights.
   - The kids are subdivided and reshaped KayKit bodies (user choice:
     "custom imp + upgraded kids").
3. **Bake lighting into textures** (LoL style). In Godot, `_painted`
   materials use lambert wrap, no specular, and a soft rim. The
   hand-painted light stays readable at night.
4. **Outline only on characters and imps** (an inverted hull, 0.022).
   This helps readability in fights, while props stay soft.
5. **Foliage has no edge highlight.** Separate canopy clumps produced
   bright seams where they intersect.
6. **Icon-first UI for kids.** Text is limited to one or two words
   ("Day 1", "Go!", "Make!"). Counts are numbers only. Glyphs are drawn
   in code (`HudWidgets.Glyph`), so they need no extra assets.
7. **Sibling task label removed.** The HUD task icons show the task; the
   3D label only says "Zzz" when the sibling is knocked out.
