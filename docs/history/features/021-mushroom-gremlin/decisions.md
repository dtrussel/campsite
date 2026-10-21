# Feature 021: Decisions

- **Steal the most plentiful raw resource.** It hurts a little, never
  cripples, and hoarding (full stashes) becomes the tempting target.
  Crafted items (torches, snacks, bandages) are never stolen.
- **The stash is a Storage Crate if one exists.** Crates are where the
  camp keeps things, so gremlins go there first. That also pulls them
  away from the campfire and the kids.
- **Caught loot is a pickup, not an automatic refund.** The kid has to
  go and get it back. It uses the same pickup as Glow Shards, shown as
  the item's HUD icon.
- **Gremlins come early in the wave** (the first half), while the imps
  keep everyone busy. Beasts still come late.
- **Separate `sneak_*` spawner fields** instead of a generic list. There
  are three mob roles now; if a fourth comes, refactor to a list of
  wave entries.
