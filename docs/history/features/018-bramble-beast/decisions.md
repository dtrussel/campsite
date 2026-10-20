# Feature 018: Decisions

## The beast

- **Siege behaviour instead of chasing.** The beast ignores anything
  beyond 2 m and heads for the nearest building (any `repairable`
  `Building`: fences, watch posts, glow lanterns). With no buildings left
  it goes for the campfire. This gives buildings and repair a job at
  night, and gives kids a clear "go stop it" moment.
  - Traps have no collision and are not in the `repairable` group, so
    the beast walks onto them. That is intended: a trap holds it.
- **Same rig as the imp.** Skeleton_Minion gives it every animation for
  free. The body is re-proportioned to a gorilla shape (stumpy legs,
  huge forearms) and scaled to 0.95.
- **Knockback 0.15 of an imp's**, so hits feel like hitting something
  heavy.
- **Always drops a shard.** It is the "big one"; the reward should be
  certain.

## Balance

- **The balance sim now plays an active player** ("fight" chases the
  nearest mob), and heals Leo at each nightfall, because the sim skips
  the day that would regenerate him.
  - With that sim, every companion task wins 3 nights, but Leo ends
    night 3 at 1–17 HP. A close call, as the playtest doc targets.
  - `no_beasts` gives about 24 HP.
  - The sim uses no fences, torches, traps or snacks, so real players
    have more margin.
- **First pass was too strong** (5 damage every 1.6 s, 45 HP): an idle
  campfire lost 150 HP to one beast in about 48 s. Tuned to 4 damage
  every 1.8 s and 40 HP.
