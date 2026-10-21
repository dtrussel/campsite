# Hero core

Status: ready-for-agent

Split into tickets in `issues/` (01&ndash;05); the `Blocked by:` lines give the order. From the 2026-10-21 architecture review, candidate 1 (the shared hero core). Rough size: **L**. Blocked by: none. It blocks tool tiers.

## Problem Statement

Leo and Nela are each played two ways: as the player's hero, and as the companion. Each way has its own controller, and the two controllers have grown into two copies of the same hero. About 200 lines are written twice:
- taking a hit, healing, regen and the invulnerability window;
- attacking and attack reach;
- the signature tool;
- gathering;
- the stat bumps on level-up;
- the small queries (nearest mob, node radius, flat distance).

The copies have already drifted:
- **Being downed:** it is modelled two ways, with two signals that different listeners subscribe to.
- **A small fallback value:** it differs between the copies.
- **The perk picker on level-up:** it depends on the order autoloads happen to connect their signals.

For the player, the risk is that a fix or a perk works for one role and not the other. For the people changing the code, any change to "a hero" means editing both files and keeping them in step. Tool tiers, the next feature on the board, would add its tier effects to both copies again.

Outside code also reads controller internals by name, such as the knocked-out flag, the current command as a magic number and the raw attack range. The smoke test pokes private state (the state enum, the private attack method, the current-damage field and the invulnerability timer), so any change to the inside of a controller breaks the tests.

## Solution

One **Hero** module holds everything a hero does whichever role it plays: health, attack, progress, gathering and the shared queries. The two controllers extend it and keep only what belongs to their role:
- **The player role** keeps input, pointer commands and the hit feel (the wind-up and hit-stop). When the player's hero is downed, the run ends.
- **The companion role** keeps the task AI and the stuck watchdog. When the companion is downed, it revives at dawn.

A small **Party** lookup answers "who is the player's hero, who is the companion, who is the other hero", so no module has to find heroes by group name.

For the player, nothing changes, except that the small drifts between the copies are settled one way. Tool tiers then adds its effects in one place.

## User Stories

1. As a player, I want Leo to take hits, heal and regenerate the same way whether I play him or he is my companion, so that the game feels fair in both roles.
2. As a player, I want Nela to do the same, so that swapping heroes doesn't change the rules.
3. As a player, I want a perk that changes damage taken to work on my companion as well as on my hero, so that companion perks are worth having.
4. As a player, I want the companion's attack reach to follow the same rules as mine, so that its range perks and signature tool behave as their cards say.
5. As a player, I want the companion to keep reviving at dawn when downed, so that losing it isn't the end of the run.
6. As a player, I want the run to still end when my own hero is downed, so that the stakes stay the same.
7. As a player, I want the perk picker to open after my level-up stats are applied, so that the new HP shows when I choose.
8. As a player, I want my attacks to keep their wind-up and hit-stop, so that combat still feels the same.
9. As a player, I want the companion to keep its quick, sparkly hits, so that it reads differently from me.
10. As a player, I want gathering to start, cancel and finish the same way for both heroes, so that the companion never gets stuck on a resource I can gather.
11. As a player, I want the signature tool (the Big Stick or the Slingshot) to apply the same way in both roles, so that crafting it helps whichever hero I play.
12. As a player, I want mobs to stop chasing a downed hero in either role, so that a downed companion isn't swarmed.
13. As a player, I want pickups and HUD cues to know when a hero is down in either role, so that the screen always matches what happened.
14. As a player, I want existing saves to keep working, so that my run in progress isn't lost.
15. As a maintainer, I want one place that defines how a hero takes a hit, so that a fix there fixes both roles.
16. As a maintainer, I want one place that defines how a hero attacks, so that tool tiers adds burn, double shot and pierce once.
17. As a maintainer, I want a hero to have one "downed" state and one signal for it, so that listeners don't have to know which role they are watching.
18. As a maintainer, I want a single "leveled" signal emitted after the stats are applied, so that the perk system doesn't race the controllers.
19. As a maintainer, I want a Party lookup for the player's hero, the companion and the other hero, so that I stop writing group-name lookups.
20. As a maintainer, I want the pointer commands to ask the hero whether it is attacking, so that they stop comparing a magic number.
21. As a maintainer, I want outside code to ask whether a hero is down through the Hero interface, so that renaming a private field can't silently break mobs or pickups.
22. As a maintainer, I want each role script to hold only its own behaviour, so that I can tell at a glance what makes the companion different.
23. As a coding agent, I want "a hero takes a hit" to live in one module, so that I read one file instead of four.
24. As a coding agent, I want the copies that have drifted to be settled and the choice written down, so that I don't reintroduce a difference.
25. As a test author, I want to hit, heal and level a hero through its public interface, so that refactoring the inside doesn't break my test.
26. As a test author, I want to run the same checks on Leo and Nela, in both roles, from one loop, so that role differences are caught.
27. As a test author, I want to read a hero's attack damage and reach through its interface, so that I don't poke private fields.
28. As a test author, I want no test to rely on enum values or task numbers, so that adding a state doesn't break unrelated tests.

## Implementation Decisions

- **A shared base class**, chosen over child component nodes (decided 2026-10-21): the Hero module is a script both controllers extend. Outside callers keep talking to the same node, and scenes don't gain extra nodes.
- **The Hero interface:**
  - **Health:** take damage (amount, source), heal (amount), whether the hero is down, revive (to an HP value), max and current HP, and one `down_changed(is_down)` signal.
  - **Shared health rules:** regen and the invulnerability window live inside the module.
  - **What each role decides:** what being downed means for the run.
- **Attack:**
  - **The interface:** attack (target), reach, whether the hero is ready, current damage, and whether the hero is attacking.
  - **What it covers:** the module owns the cooldown and the melee vs pebble branch.
  - **Perks:** it calls the existing perk-hit module for perk effects, which stays as the perk math underneath it.
  - **Tool tiers:** it exposes a tier value and an on-hit hook, both unused until tool tiers.
  - **What each role adds:** the player role adds its wind-up, range re-check and hit-stop around the shared attack; the companion role adds its sparkle.
- **Progress:**
  - **Stats:** they are set up once from the hero definition. On level-up, the module applies the stat bumps and then emits `leveled(level)`.
  - **The perk system:** it reacts to `leveled`, not to the progression manager's raw level-up, so the picker always opens after the stats change.
- **Gathering:** start (node), cancel, whether gathering is active, and a `finished` signal. Both roles use the typed path; there are no `has_method` checks.
- **Shared queries:** nearest mob, node radius and flat distance become one copy in the module.
- **The signature tool:** applying it is one method on the module. The hero definition's role-prefixed fields (the companion attack range, cooldown and signature range factor) stay as data, read by the module according to role.
- **Drifted values:**
  - **The node-radius fallback:** settled on the player's value, 0.4.
  - **Repair and build reach and tap constants:** they stay role-specific, as role tuning.
  - **The stuck watchdog:** it stays companion-only.
  - **Record the choices:** each settled value is written in the module's comments.
- **Signals:**
  - **One signal:** `knocked_out` and `knocked_out_changed` merge into `down_changed`.
  - **Listeners:** the game manager (which ends the run when the player's hero is down), the HUD and the bark director move to it.
  - **The old names:** they are removed, not aliased.
- **Party:**
  - **What it is:** a small lookup with the player's hero, the companion, the other hero (given a hero), both heroes, and the role of a hero.
  - **Who switches to it:** the perk-hit module's other-hero lookup and the perk manager's role branches.
  - **The rest:** other group-name lookups move to it where they are touched, without a sweep of every file.
- **Outside callers:**
  - **Is the hero down:** mobs, pickups, the perk-hit module and the pointer commands read it through the Hero interface.
  - **Attack state and range:** the pointer commands use "is attacking" and "reach".
- **No behaviour changes** beyond the settled drifts. The save format is unchanged; the save reads the same fields through the Hero interface.

## Testing Decisions

- **Test only behaviour through the interface.** That means hit, heal, down, revive, attack damage, reach, level-up and gathering through the Hero interface and Party. No test reads a private field, an enum value or a task number.
- **The seam** is the Hero interface on the real heroes in the running game. The smoke run already boots the main scene, so tests use it and add no new seam.
- **One new scenario** loops over both heroes in both roles and checks:
  - a hit lowers HP;
  - the invulnerability window blocks a second hit;
  - heal raises HP;
  - downing emits `down_changed`;
  - the companion revives at dawn;
  - level-up raises max HP before `leveled` fires;
  - attack damage and reach match the definition, and the signature tool changes them.
- **Existing scenarios:** the ones that poke the state enum, the private attack method, the current-damage field or the invulnerability timer are rewritten against the interface. All existing smoke and validate checks stay green.
- **Prior art:** the perk-card scenarios in the smoke run, which already drive both heroes through public calls and the perk manager.

## Out of Scope

- Tool tiers itself (only the tier slot and the on-hit hook are added, unused).
- Moving HUD game rules into their managers (review candidate 4).
- The typed HUD seam and the run narrator (review candidate 5).
- Saving and resetting (the run-lifecycle spec).
- New hero behaviour, new perks or balance changes.

## Further Notes

- Do this before tool tiers, whose tickets are now blocked by this spec.
- The architecture review report: https://claude.ai/artifact/V3mStF5e7Qv6ypXTjwzWCg (private to the project owner).
- The run-lifecycle spec builds on this one: each hero saves and loads itself through the Hero interface.

## Comments

- **2026-10-21, to-tickets:** split into tickets 01-05; the user approved the breakdown.
