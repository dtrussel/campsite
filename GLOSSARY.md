# Glossary

The words this project uses for its own concepts. Use them in code, tickets and docs. Story and world terms (the Moon Lantern, the Moon-Eater, mobs, places) are defined in `docs/design/story.md` and `docs/design/game-design-spec.md`.

## Heroes

- **Hero:** Leo or Nela. A hero takes hits, heals, attacks, gathers and levels up the same way whichever role it plays. The shared Hero module holds that behaviour. *Avoid:* "player" when you mean either hero.
- **Role:** how a hero is being played, either **the player's hero** (driven by input and pointer commands) or **the companion** (driven by its task AI). Each role adds only what differs: the player's hero ends the run when it is down, and the companion revives at dawn.
- **Party:** the two heroes of a run, and who plays which role. Ask the party for "the player's hero", "the companion" or "the other hero" instead of looking heroes up by group name.
- **Down:** a hero at 0 HP. *Avoid:* "knocked out" in new code.
- **Signature tool:** a hero's crafted tool (Leo's stick, Nela's sling).
- **Tool tier:** one step of a hero's signature tool, crafted at the Crafting Table in order (tier 1: the Sturdy Stick or the Slingshot; up to tier 3). *Avoid:* "upgrade level".
- **Perk:** a card picked at level-up that changes a hero's stats or hits.

## Runs

- **Run:** one play from hero select to a win or a loss. A run ends at the end screen. It is made of days and **nights**, and each night ends at **dawn**, when the game autosaves.
- **Run state:** everything that belongs to one run and is gone when it ends. That includes resources, levels, perks, the time of day, the campfire, buildings, blueprints, torches and the heroes. It lives in the run save.
- **Saving system:** any module that holds run state. It saves, loads and resets its own state.
- **Run session:** the one module that starts, continues and resets a run. It walks the saving systems in a declared order and says when a restore has finished.
- **Run config:** what a run starts from: the party, the chapter goal, the seeds, and test settings such as the perk auto-pick time.
- **Continue:** resuming a run from its save.

## Across runs

- **Profile:** what a player keeps across runs, such as the story beats seen, chapters won, records and (later) badges. It is never deleted when a run ends. *Not* device settings (audio, look, auto-attack), which live apart.
- **Record:** a best value kept in the profile, like the most nights survived in endless mode.

## Building

- **Blueprint:** a placed building that isn't finished yet. Heroes build it up, and refunds give back what was paid for it.
- **Shard:** the rare drop that feeds the Moon Lantern, Glow Lanterns and (later) tool tiers.
