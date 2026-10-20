# Feature 034: Test plan

- **Checks.** `tools/check.sh` must report validate OK and smoke PASSED.
  - Validate: every roster hero has a model, stats, a portrait and a known signature recipe; at least two heroes.
  - Smoke, hero scenario: the select screen opens on the last pick, selects and wraps; playing Nela puts Nela in the player shell and Leo in the companion shell with their own body, health and reach; the HUD shows Nela; a pebble hits an imp 3.5 m away on impact; the Slingshot upgrades Nela and the Sturdy Stick upgrades Leo; the save holds the party and Continue plays Nela again; old saves are Leo with Nela.
- **Screenshots** (`tests/sim/screenshots.tscn`): `01c_hero_select_leo`, `01d_hero_select_nela` and `10_nela_hud`. The heroes stand clear of the cards, nothing hides them, and the HUD names are right.
- **By hand.** Left / Right (or A / D) switch heroes, Enter starts, Esc goes back to the title; the Continue tooltip names the saved hero.
