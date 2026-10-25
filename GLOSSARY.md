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
- **Run config:** what a run starts from, fixed until the run ends: the party, the chapter (or an endless run), the nights to win, the seeds, and test settings such as the perk auto-pick time. The run config also answers the run's rules: which night the Moon-Eater comes, which dawn wins, how far an endless run is past the story. *Avoid:* inferring the chapter from the run length.
- **Endless run:** a Chapter 2 run with no win and no Moon-Eater; it ends only in a loss, and how far it got can set a record.
- **Continue:** resuming a run from its save.
- **Run outcome:** how a run ended, as the profile hears it: the run config, whether it was won, the night it ended on and the run's stats.

## Across runs

- **Profile:** what a player keeps across runs, such as the story beats seen, chapters won, records, badges, journal pages and unlocks. It is never deleted when a run ends. *Not* device settings (audio, look, auto-attack), which live apart.
- **Badge (Camp Badge):** a Scout-style milestone kept in the profile, such as First Night or Builder. Earned once, for good.
- **Journal page:** a page of Mum's journal, kept in the profile once found. Mum's dawn notes are pages; the rest come from a **day chest** (at most one a run, at the map edge) or a badge. Read in the scrapbook's Journal tab.
- **Scrapbook:** the screen the title's Journal button opens, with a Badges tab and a Journal tab.
- **Unlock:** something the profile opens for good, such as Chapter 2 (by winning Chapter 1), Endless (by winning Chapter 2), a cosmetic tint or a starting perk (by a badge). Unlocks are sideways or small, never a big head start.
- **Record:** a best value kept in the profile, like the furthest night an endless run reached.

## Building

- **Blueprint:** a placed building that isn't finished yet. Heroes build it up, and refunds give back what was paid for it.
- **Shard:** the rare drop that feeds the Moon Lantern, Glow Lanterns and (later) tool tiers.
