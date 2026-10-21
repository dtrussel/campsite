# Feature 008: Decisions

1. **The kids are fully custom meshes on the unchanged KayKit rig.**
   - Rogue and Mage share the same skeleton and the same 76 clips, so every scene's clip map keeps working.
   - Soft clothing is made of fused, auto-weighted pieces. Separate overlapping pieces give crisp hems.
   - Gear is rigid, bound to one bone.
2. **Faces are single-sided decals** floating 3–9 mm above the head.
   - They stay crisp at any texture resolution.
   - The ink-outline pass (which draws back faces) does not ring them.
   - The head has its own 1024 px texture for sharper portraits.
3. **Open hems are left single-sided.** The outline pass draws the inside dark, which reads as the shadowed inside of a sleeve.
4. **Leo's weapon is his walking stick,** from the concept art and friendlier for kids. **Nela carries the lantern.** Both are built in the `handslot.r` frame, where local +X points down in the idle pose.
5. **Ground textures are painted in numpy**, not rendered, so they tile perfectly and rebuild in seconds.
