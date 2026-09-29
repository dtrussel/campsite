# Feature 021: Mushroom Gremlin

## Goal

A third enemy that attacks the camp's **supplies** instead of its HP. It
gives the stash caps and Storage Crates (019) a story, and gives kids a
"catch the thief!" chase.

## Scope

- **Art.** `art/characters/mushroom_gremlin.py`: a small pale stem body,
  a big spotted purple cap, glowing green eyes and a patched loot sack.
  It is built on the Skeleton_Minion rig, so it shares the imp's
  animations. 7.2k triangles; scale 0.55 in game.
- **Thief behaviour** (`MobDefinition.steals_resources`, `steal_amount`):
  - It ignores the kids.
  - It runs to the stash: the nearest Storage Crate, else the campfire.
  - It takes up to 4 of the camp's most plentiful raw resource. Crafted
    items are never taken.
  - Then it runs back to where it came out of the ground.
  - **Caught:** the loot drops as a pickup showing the item's icon and
    "x4". Walk over it to get it back.
  - **Escaped:** the loot is gone (`stolen_lost` stat).
- **Stats:** 8 HP, fast (3.1), 8 XP. It gets knocked back further than
  an imp. Traps and torches work on it.
- **Waves.** `MobSpawner.sneak_definition` and `sneak_counts` = 0, 1, 1
  for nights 1–3, then +1 per night. Gremlins are mixed into the first
  half of the wave.
- **HUD banners:** "Mushroom Gremlin!", "Thief! -4 Stone" and "It got
  away with 4 Stone!".
- **Effects and sounds:** a spore puff and giggle as it appears, a
  "yoink" jingle when it steals, and a spore pop and squeak when caught.
