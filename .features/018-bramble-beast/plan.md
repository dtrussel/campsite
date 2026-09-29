# Feature 018: Bramble Beast

## Goal

Add a second enemy that changes what you do at night. Imps rush the
campfire and anyone nearby. The **Bramble Beast** is slow and tough, and
walks to your **buildings** to tear them down. So fences and posts are
now worth defending and repairing (feature 017), and Leo has to go out
and meet it.

## Scope

### In

- **Art.** `art/characters/bramble_beast.py` builds a hulking body of
  bark and moss with thorns, club fists, a leafy crown and ember eyes,
  on the Skeleton_Minion rig. It reuses the imp's animations. 9.2k
  triangles.
- **Data-driven behaviour** (new `MobDefinition` fields):
  - `prefers_buildings`: walks to the nearest standing building before
    the campfire;
  - `building_damage_multiplier`: ×3 against buildings;
  - `knockback_scale`: 0.15, so it barely flinches;
  - `spawn_burst` and `death_burst`: its own effects and sounds.
- **Stats:** 40 HP, speed 1.5, 4 damage every 1.8 s (12 against
  buildings), aggro radius 2 m (it mostly ignores the kids), 15 XP. It
  always drops a Glow Shard.
- **Waves.** `MobSpawner` builds each night as imps plus heavy mobs:
  - 0, 1, 2 beasts on nights 1, 2, 3, and +1 for each later night;
  - beasts are spread over the second half of the wave.
- **HUD.** A "Bramble Beast!" banner when one appears.
- **Sounds.** A groan with creaking wood as it rises; a branch crack and
  falling leaves as it dies.

### Out

- **Mushroom Gremlin (steals resources), Night Crow.** Later mob features.
