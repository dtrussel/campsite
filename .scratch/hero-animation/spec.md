# Hero animation

Status: ready-for-agent

From a `/grill-with-docs` session on 2026-10-25. The user asked to improve the game's graphics, especially the main characters' animation, following current best practice. The session narrowed that to the two heroes' animation; any other graphics work becomes its own feature.

## Problem Statement

Leo and Nela are the characters the player watches all game, but they move like stock mannequins. Their clips come straight from the KayKit adventurer rig, which was made for adult adventurers, not chibi kids:

- **Wrong moves.** Nela's sling shot plays a spell cast, and building plays a two-handed axe chop.
- **No personality.** Leo and Nela walk, run, idle and cheer identically.
- **Rigid gear.** Hair, backpacks and hanging gear are glued to a single bone, so nothing swings or settles when a kid turns, stops or gets hit.
- **Weak hits.** A hit lands the instant the attack starts, so the swing cannot wind up, and nothing marks the impact.
- **Frozen faces.** The painted faces never blink or change.

Every mob already has hand-keyed clips of its own (features 026–028), so the heroes now look less alive than the imps they fight.

## Solution

Give both heroes their own hand-made motion, built the way the mob clips are built: keyed in Blender Python on the existing rig, committed as part of the model, with no external animation assets. Then add three runtime layers that react to play:

1. **Personality clips.** Every logical state the heroes use gets a new clip, plus a few idle fidgets. Leo and Nela get their own clips wherever personality or their signature tool shows. Attacks wind up briefly and land on a **contact frame**.
2. **Secondary motion.** Hair, backpacks and hanging gear ride short spring chains, so they lag, swing and settle.
3. **Game feel.**
   - **Hit-stop** on the attacker and the target, and a small squash on the target.
   - A **head look-at** that shows what each kid is paying attention to.
   - Walk and run cycles whose stride matches the hero's real speed, so the feet don't slide.
4. **Faces.** The kids blink, and their eyes and mouth change for a hit, a cheer and being down.

Each layer ships on its own. A hero state without a new clip keeps its stock clip, so nothing breaks partway through. Gameplay balance does not change: attack cadence, damage, reach and action durations stay as they are.

## User Stories

### Playing

1. As a player, I want Leo to swing his stick with a visible wind-up and follow-through, so that each hit feels like it connects.
2. As a player, I want Nela to pull her sling back and release it when the pebble flies, so that her attack looks like a sling shot and not a spell.
3. As a player, I want the hit to land at the moment the stick strikes or the sling lets go, so that what I see and what happens agree.
4. As a player, I want attacks to still feel instant when I press, so that the wind-up never makes the game feel sluggish.
5. As a player, I want a short freeze on the attacker and the target as a hit lands, so that hits feel weighty.
6. As a player, I want the rest of the game to keep running during that freeze, so that the companion, timers and other fights never stutter.
7. As a player, I want a mob to squash slightly when hit, so that I can see which one I struck.
8. As a player, I want Leo and Nela to move differently (Leo bouncy and eager, Nela lighter and more careful), so that I can tell them apart at a glance and they feel like characters.
9. As a player, I want the kids' hair, backpacks and gear to swing and settle when they turn, stop or get hit, so that they feel physical.
10. As a player, I want the kids' feet to stay planted while they walk and run, so that they don't look like they're skating.
11. As a player, I want a kid to look at the mob they're fighting, so that I can read who is targeting what.
12. As a player, I want a kid to look at the tree, rock or building they're working on, so that gathering and building read clearly.
13. As a player, I want an idle kid to glance at a nearby mob at night, so that the camp feels tense and the kids feel aware.
14. As a player, I want the kids to glance at each other now and then, so that they feel like siblings and not two robots.
15. As a player, I want a kid standing still to fidget now and then (look around, scratch, stretch, check their tool), so that waiting doesn't look frozen.
16. As a player, I want the kids to blink, so that their faces look alive.
17. As a player, I want a kid's face to wince when hit, beam when cheering and look dazed when down, so that I can read how they're doing without the HUD.
18. As a player, I want the build, repair, chop, pick-up and tinker actions to look like a kid doing that job, so that the camp work reads.
19. As a player, I want the hit reaction, going down and getting back up to fit a kid's size and weight, so that they don't move like an adult soldier.
20. As a player, I want the cheer to show each kid's personality, so that wins and level-ups feel like theirs.
21. As a player, I want none of these effects to move or shake the camera, so that the game stays comfortable for young players.

### Companion and other screens

22. As a player, I want the companion to use the same new clips, contact frame, look-at, springs and faces, so that both kids feel equally alive whichever one I play.
23. As a player, I want hero select to show the new idle, fidgets and cheer, so that I meet each kid's personality before the run.
24. As a player, I want Mum to blink and her hair and pack to sway where that costs nothing extra, so that she matches the kids in story beats.

### Making and keeping the art

25. As an art contributor, I want the hero clips to be generated by a script, as the mobs' clips are, so that anyone can rebuild them from source without hand-editing in Blender.
26. As an art contributor, I want the shared clips to take per-kid style knobs (bounce, arm swing, posture), so that one clip set gives each kid their own feel.
27. As an art contributor, I want clay contact sheets and GIFs of every clip from the game camera, so that I can review motion without launching the game.
28. As an art contributor, I want old and new in-game captures side by side, so that I can judge each change against what it replaces.
29. As a maintainer, I want an automatic check that walk and run feet don't slide beyond a set amount, so that later tweaks can't quietly bring sliding back.
30. As a maintainer, I want an automatic check that looping clips wrap without a pop, so that idles and cycles stay seamless.
31. As a maintainer, I want an automatic check that each attack's contact frame is within the wind-up cap and that action clips keep their gameplay durations, so that animation work never changes balance.
32. As a maintainer, I want any hero state without a new clip to fall back to its stock clip, so that each ticket ships on its own.
33. As a maintainer, I want the kids to stay within the hero triangle budget after the new bones and face atlas, so that performance doesn't regress.
34. As the product owner, I want to sign off each layer visually from the contact sheets and in-game captures, so that "better" is my call, backed by numbers.

## Implementation Decisions

### Scope and sources

- **The heroes only.** The heroes are Leo and Nela, whether played or companion. Mum gets the springs and the blink only where her rig and head take them at no extra cost. Mobs, the Moon-Eater and the little golem are untouched.
- **Clip source.** Clips are hand-keyed in Blender Python on the existing KayKit rig, extending the shared clip helpers the mobs use (poses in rest axes, mirroring, keying).
  - The clips are exported inside each kid's model.
  - No Mixamo, bought packs, AI motion or GUI-keyed clips.
  - The logical-state-to-clip mapping on each hero's definition stays the one switch between stock and new clips.
- **Engine.** We stay on Godot 4.3, so the spring chain and the look-at are two small `SkeletonModifier3D` scripts. They can give way to the built-in spring and look-at modifiers if a later feature upgrades the engine. No ADR: either choice is easy to undo.

### The clip set

- **One for one.** Every state the heroes use today gets a new clip: `idle`, `walk`, `move` (run), `attack`, `hit`, `death`, `getup`, `cheer`, `gather`, `chop`, `pick`, `tinker` and `hammer`.
- **Idle fidgets.** Each kid gets 2–3 fidgets that play now and then while idle. The character visual picks them at random intervals, and only when the hero is idle and not in an action.
- **Nothing more.** No run-start or run-stop clips (they cost responsiveness in a top-down game) and no attack combos (a gameplay change).
- **Who owns which clip.**
  - Each kid has their own `idle`, fidgets, `attack` and `cheer`, and their own run where the personality needs it.
  - Everything else is one shared set, keyed once and varied per kid by a few style knobs (bounce, arm swing, posture) applied when the clip is generated.
- **The 12 principles.** The clips follow them throughout: anticipation, follow-through and overlap, squash and stretch within the rig's limits, arcs and exaggeration suited to chibi proportions.
- **Gameplay durations.** Action clips keep the durations gameplay relies on. The build beat and gather already read their length from the clip, so the new clips are authored to the same lengths at their current play speeds.

### Contact frame

- **The hit lands on the contact frame.**
  - Today an attack applies its hit (Leo's swing) or fires its pebble (Nela) the moment it starts.
  - Now the attack starts the animation and the cooldown at once, as before, and applies the swing or fires the pebble at the attack clip's contact frame.
  - Both roles get this through the shared Hero module, which already owns the swing and the shot. Only the timing moves.
- **The wind-up is capped.** The contact frame comes at most about **0.1 s** after the attack starts, at play speed. The cooldown and its HUD ratio are unchanged, so attacks per second and balance stay the same.
- **Where the contact time lives.**
  - Each attack clip's contact time is data on the hero definition, next to its clips.
  - The clip script is the source of that number and prints it when it builds, and the validator checks that the two agree.
  - A hero without a contact time keeps today's instant hit, which is the stock-clip fallback.
- **During the wind-up:**
  - **Down:** a hero who goes down cancels the pending hit.
  - **Hit:** a hero who is hit does not cancel it, so the game stays forgiving for young players.
  - **Target gone or out of reach:** a melee hit whose target has died or left reach by the contact frame misses quietly, as an out-of-reach attack does today.
  - **Pebbles:** a pebble fires toward the target's position at the contact frame.

### Game feel

- **Hit-stop.**
  - When a hero's hit lands, the attacker's and the target's animation and visual freeze for about **40–60 ms**. Gameplay time, timers, the companion, other mobs and the camera keep running.
  - The target also gets a small squash and recovery on its visual.
  - Only the visuals freeze; the hit's damage and knockback apply on the frame they land.
- **Head look-at.**
  - A look-at modifier on the head and chest picks its target in this order:
    1. the attack target while fighting;
    2. the resource or building being worked on while gathering or building;
    3. the nearest mob within about **6 m** while idle at night;
    4. otherwise, the other hero now and then.
  - The look is capped at about **60°** of combined head and chest turn, and it blends out during full-body actions (`hit`, `death`, `getup`, `cheer` while standing).
  - The player's hero and the companion follow the same rules.
- **Stride matching.**
  - Walk and run cycles are authored with a known stride length, and their playback is scaled by the hero's real speed (extending today's run scaling to walk), so the feet don't slide.
  - No foot IK: the camp is flat and the camera is top-down, so IK would add cost and jitter for little gain.
- **No camera effects.** No reduced-motion setting is added, and nothing in this feature shakes, zooms or flashes the camera.

### Secondary motion

- **New bones.**
  - The kid model builder adds short chains (2–3 bones each) for whatever visibly hangs or sticks out on each kid's turnaround sheet: hair locks or a tail, the backpack, and hanging gear such as straps or Nela's lantern.
  - Those parts are weighted to the new bones instead of being bound rigidly to one.
  - No clip keys these bones, so all existing clips keep working.
- **Spring chains.**
  - A runtime spring-chain modifier moves each chain from the bones' motion, with stiffness, damping, gravity and a reach limit per chain, tuned per kid on the hero data.
  - It reacts to real turns, stops, hits and hit-stop.
  - It is a property of the character visual, so the companion and hero select get it too.

### Faces

- **A face atlas.**
  - Each kid's eyes and mouth become a small painted atlas of states: open, closed (blink), happy, hurt and dazed.
  - The face shader picks the cell at runtime, while the rest of the face stays in the baked head texture.
  - The atlas is painted with the existing face painter, so it matches today's look.
- **What drives the face.** Blinks come at random intervals, with an occasional double blink. The `hit`, `cheer` and down states set the expression for their duration and then return to neutral.

### Interfaces that change

- **Character visual.**
  - It gains the idle fidgets, the spring chains, the look-at (with a way for gameplay to set or clear the focus), hit-stop and the face state.
  - Its existing calls stay as they are: set locomotion, play action, face, play final.
  - Play action still returns the clip length, and the visual also reports when an action's contact frame comes.
- **Hero definition.** It gains each attack clip's contact time, the per-kid spring tuning and the face atlas reference.
- **Hero module.** It applies the swing or fires the pebble at the contact frame instead of at once, and asks the visuals for hit-stop when a hit lands.
- **Kid model scripts.** These are the shared kid kit plus Leo's and Nela's builders. They add the spring bones, weight the hanging parts to them, generate and export the new clips, and bake the face atlas.

### Budgets

- The kids stay within the hero triangle budget (≤ 40k) and the 1024 bake.
- The face atlas is one small extra texture per kid.
- The spring and look-at modifiers run only on the two heroes and Mum, so their per-frame cost is negligible.

## Testing Decisions

- **What a good test is.** It checks behaviour a player or maintainer can see from outside: when a hit lands, whether a foot slides, whether a loop pops, what a kid looks at. It does not check how the tree, the modifiers or the clips are built inside. Visual quality is not tested automatically; the user signs it off from the contact sheets and captures.
- **Seams.** Prefer the existing ones:
  - **The project validator.** It loads every hero's model and checks its clips as data:
    - every mapped state has a clip;
    - looping clips wrap (their first and last poses match within a tolerance);
    - walk and run feet slide less than a set amount per stride at the hero's speed (sampling the foot bones against the root's travel);
    - each attack's contact time is within the wind-up cap and matches the clip script's;
    - action clips keep their gameplay durations.

    It runs in CI without Blender.
  - **One new smoke scenario,** a `hero_animation` script, which touches nothing shared:
    - an attack's hit lands at the contact frame and not at once, for both heroes in both roles;
    - a hero going down during the wind-up cancels the hit;
    - hit-stop freezes the attacker and the target but not the companion or another mob;
    - the look-at picks the attack target, then the work target;
    - a spring chain moves after a sudden turn and settles back within a time limit;
    - the face shows the hurt state on a hit and returns to neutral.

    Every check that follows something in flight waits on a condition, not a duration (see the test strategy).
  - **Unit tests** for the pure rules, where they can be pulled out without a scene: the look-at target priority and the blink and fidget schedulers.
- **Prior art.**
  - The character visual already exposes small test hooks (the active action layer, footstep puffs), and the existing smoke scenarios read them. New hooks follow that pattern.
  - The tool-tiers and perks smoke scripts show the scenario shape for combat timing checks.
  - The validator already checks the heroes' data.
- **Review tooling (not CI).**
  - The art script renders clay contact sheets and GIFs per clip from the game camera, extending today's clay animation frames.
  - A gallery or capture scene records old and new side by side in the game.
  - Both go into the ticket for the user's sign-off.

## Out of Scope

- Any graphics work beyond the heroes' animation (lighting, shaders, post-processing, props, environments); that becomes its own feature.
- New clips for mobs, the Moon-Eater, the little golem or Mum's story clips, other than Mum's free springs and blink.
- Upgrading Godot beyond 4.3.
- Foot IK, root motion, motion matching, run-start and run-stop clips, attack combos and other gameplay changes.
- Mocap, Mixamo, bought clip packs and AI-generated motion.
- Modelled eyelids or facial bones.
- A reduced-motion setting, camera shake and screen flashes.
- Changes to attack cadence, damage, reach or action durations.

## Further Notes

- **Delivery order** (tickets come from `/to-tickets`):
  1. the acceptance tooling (contact sheets, GIFs, captures, the validator's slide, loop and timing checks), so the stock clips have a measured baseline;
  2. personality clips with the contact frame;
  3. spring bones and chains;
  4. game feel (hit-stop, squash, look-at, stride matching);
  5. the face atlas.

  Each ships alone, with stock clips as the fallback.
- **The baseline will fail.** The validator's slide and loop numbers taken on today's stock clips are expected to fail the new thresholds. Ticket 1 records them as the baseline and leaves the checks reporting until ticket 2 turns them on.
- **Glossary.** The session added **contact frame** and **hit-stop** to `GLOSSARY.md`.
- **Docs to update as tickets land:** `art/README.md` (the hero clip script, the spring bones, the face atlas), `docs/design/art-direction.md` (a short "hero motion" section on each kid's personality) and the roadmap row when the feature is done.
- **Previous work:** feature 023 (animation layering) is the base this builds on: `docs/history/features/023-animation-layering/`.

## Tickets

Split on 2026-10-25 with `/to-tickets`. The `Blocked by:` lines give the order. Tickets 03–10 and 13 rebuild the kids' committed models, which can't be merged when built in parallel, so they run one after another. Only 01, 02, 11 and 12 run alongside.

1. `issues/01-clip-checks-and-captures.md`: the validator's slide, loop and duration checks (report-only) and the review renders and captures; records the baseline.
2. `issues/02-contact-frame.md`: hits land on the contact frame, on the stock clips.
3. `issues/03-hero-clip-script-leo-attack.md`: the hero clip script, plus Leo's stick swing.
4. `issues/04-nela-sling-attack.md`: Nela's sling wind-up and release.
5. `issues/05-walk-and-run.md`: stride-matched cycles with style knobs.
6. `issues/06-idles-and-fidgets.md`: own idles and the fidget scheduler.
7. `issues/07-reactions-and-cheers.md`: hit, death and getup, plus each kid's cheer.
8. `issues/08-work-actions.md`: gather, chop, pick, tinker and hammer at today's durations.
9. `issues/09-spring-chains-leo.md`: the spring-chain modifier and Leo's chains.
10. `issues/10-spring-chains-nela-and-mum.md`: Nela's chains, and Mum's where they're free.
11. `issues/11-hit-stop-and-squash.md`: hit-stop on the attacker and the target.
12. `issues/12-head-look-at.md`: the look-at modifier and its target order.
13. `issues/13-face-atlas.md`: blink and expressions.

The sign-off playtest is `../hand-play-backlog/issues/10-hero-animation-feel.md` (`ready-for-human`, blocked by all thirteen).

## Comments

- **2026-10-25, grilling:** scope, clip source, the four layers and their order, acceptance, the contact frame, hit-stop reach, look-at priorities, stride matching instead of foot IK, the face atlas and delivery were all agreed with the user (Q1–Q16). The wind-up rules (a down hero cancels the hit, being hit does not, a missed melee hit misses quietly) and the baseline-then-enforce plan for the validator were filled in while writing the spec; confirm or change them before `/to-tickets`.
- **2026-10-25, to-tickets:** the user approved the 14-ticket breakdown, the serialized model rebuilds, and letting 02 and 12 start before the clips are done (the faces, 13, still come last in the rebuild chain); the wind-up rules and the baseline-then-enforce plan stand.
