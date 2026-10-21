# Feature 036: Decisions

- **From the 2026-10 brainstorm.** The user chose story (B) and choices / meta (C), with an **adventure** tone (see `docs/design/story.md`), and asked for the roadmap first.
- **Shards go to the lantern by hand** (walk over and press E), not automatically, so the lantern is a place in the camp and a choice on the way back.
- **The drop moves from global modulo to a chance with pity.** This fixes a survey finding: beast kills shifted the imp drop timing.
- **Tuning.** Imps drop at 40 % with a pity of 3, about 0.51 shards per kill. Beasts drop 1 every time.
  - Chapter 1: about 14 shards drop over 3 nights. The lantern needs 11, which leaves room for one Glow Lantern (2). Expected stages: 1 after night 1, 2 after night 2, full during night 3.
  - Chapter 2: about 65 shards drop over 7 nights. The lantern needs 44 and is full around night 6, ready for the Moon-Eater (038).
- **Its own group, not the torch group.** Mobs take the strongest slow from torches and the lantern. The torch group keeps meaning "planted torches and Glow Lantern auras".
- **Light damage only for shadow creatures** (`MobDefinition.hurt_by_moonlight`, imps). Beasts and gremlins are only slowed.
- **The pedestal is a code-built stand-in** until the team's model arrives. There is no collider, so it never changes the navigation mesh.
- **The daytime perk** (an open question) is left out. The ring already matters at night, and perks come with 039.
