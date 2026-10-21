# Feature 019: Decisions

- **Stash caps, chosen by the user**, so the Storage Crate has a job.
  - Caps are 20 per raw resource. Every recipe and building needs at
    most 5 of one item, so 20 never blocks a build. It only stops
    endless hoarding.
  - Losing a crate lowers the cap but never deletes items above it.
- **Stations instead of one long list.** With 8 recipes, one panel no
  longer fit the screen. Each station shows its own 4 recipes, which also
  teaches "the table is where the upgrades are".
- **Once-per-run upgrades** (Sturdy Stick, Slingshot) use flags on Leo
  and Nela, not items. The recipe is disabled once it has been made,
  like the Stone Hearth.
- **The bandage is an item used with X**, not an automatic heal. Kids
  choose when to help Nela, and it is the only way to wake her before
  dawn.
- **Trap Refill** works only when a trap has used a snap, so it never
  wastes scrap.
- **Tests look up buildings by id** (`BuildManager.get_definition`),
  because adding buildings renumbers the keys.
