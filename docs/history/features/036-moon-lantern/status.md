# Feature 036: Status

**Done.**

- **The Moon Lantern** stands by the tent (`scenes/base/MoonLantern.tscn`, placed in `TestWorld.tscn`). It is a code-built stand-in: a stone base, a wooden post, a brass cage with a moon orb, and one crystal per stage around the base.
- **E next to it hands over** the stash's Glow Shards, but only as many as it still needs. A prompt "E  Moon Lantern" shows when you're close and carry shards.
- **Stages:**
  - Chapter 1 has 3 stages, costing 2, 4 and 5 shards.
  - Chapter 2 has 6 stages, costing 3, 5, 6, 8, 10 and 12.
  - Each stage raises the orb's glow and light, lights a crystal, and widens a moon-blue ring on the ground (radius 4 → 9 m).
- **Inside the ring:**
  - all mobs move at 70 % speed (a torch is stronger, and the strongest slow wins);
  - imps (`hurt_by_moonlight`) take 1 damage every 1.5 s;
  - from 80 % lit on (stage 3 of 3, stage 5 of 6), Mushroom Gremlins turn back at the ring's edge.
- **Shard drops:**
  - imps drop with a 40 % chance and a pity of 3 (never more than 2 kills in a row without one);
  - beasts always drop;
  - counted per mob type, with `GameManager.roll_loot` and `MobDefinition.rolls_drop`.
- **HUD:**
  - a moon dial left of the top strip fills slice by slice;
  - a banner says when the lantern glows brighter;
  - the dawn card tells you how many shards the next stage needs.
- **Save:** `lantern.shards` is saved and restored. Older saves (same VERSION 1) start the lantern dark.
- **Checks:** `tools/check.sh` smoke covers delivery, ring radius, the slow, light damage, the gremlin ward, the save round-trip, Chapter 2's 6 stages, and a seeded 100-kill drop test.
