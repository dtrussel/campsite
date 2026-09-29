# Feature 025: Decisions

- **Separate glow meshes.** The jack-o'-lantern face and the lantern
  flame are their own emissive meshes (`flat_material`), so they glow
  at night without lighting up the painted texture.
- **Low budgets for the backdrop.** Hills and mountains are about 1k
  triangles each: they sit far away and are mostly hidden by the border
  trees.
- **Pruned the unused packs.** Nothing referenced the Halloween or
  Hexagon models any more (checked with grep across scripts, scenes,
  tools, tests and art), so they were removed rather than kept as dead
  weight in the export.
- **KayKit stays for characters.** The rigs and animations (and the axe
  icon model) are still KayKit; replacing them is a much larger job.
