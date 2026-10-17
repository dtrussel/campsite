# Story bible: "The Dark Moon"

> Companion to [`game-design-spec.md`](game-design-spec.md). Status:
> **planned** (features 035&ndash;042, see
> [`docs/roadmap/roadmap.md`](../roadmap/roadmap.md)). Nothing here is in
> the game yet. Names marked *(working)* are open for the team.

## Tone

An **adventure** with stakes and a mystery that unfolds over several
runs. It is not a cozy story where nothing is ever wrong.

- Something is really wrong: mum is missing and the moon has gone dark.
  The kids must be brave, and the player should feel it.
- It is never gory, cruel or hopeless. Shadows are made of what the
  forest lost, not of evil people. Every chapter ends on hope.
- Short sentences a 7-year-old can read, or have read to them. One
  idea per card and at most two lines of dialogue at a time.
- The art stays in the team's storybook paintings (`docs/design/art-direction.md`).

## Premise

Leo and Nela are camping at the edge of the **Hollow Wood** with
their **mum**, a forest ranger *(working: mum vs. Grandpa)*.

On the first evening the moon goes **dark**. Mum takes her ranger
lantern, tells the kids to keep the campfire burning no matter what,
and walks into the woods to find out why. She does not come back.

When the light goes, the shadows come: imps, bramble beasts and thieving
gremlins. The campfire is the only light left, and the kids have to hold
it until mum comes home.

## The mystery (revealed across runs)

| Layer | What the player learns | Where |
|---|---|---|
| 1 | The Glow Shards the shadows drop are **pieces of the moon's light**. | First shard pickup (035/036) |
| 2 | Long ago a **Moon Lantern** stood by the camp and kept the Hollow Wood calm at night. Someone has to rebuild it. | Dawn cards, night 1&ndash;2 (035) |
| 3 | Mum knew about the lantern: her **field-journal pages** are hidden around the woods. | Day chests, badges (041) |
| 4 | The shadows are not evil. They are made of **everything the forest lost** (fallen trees, lost toys, forgotten paths) and they are cold, so they crowd toward light. | Journal pages (041) |
| 5 | At the heart of the Hollow sits the **Hollow King** *(working)*. It is the biggest, loneliest shadow. It swallowed the moon's light, and mum's lantern with it. | Chapter 2 finale (038) |

## Run structure: chapters

The two run lengths become chapters of one story.

### Chapter 1: "The Dark Moon" (3 Nights)
- **Intro:** mum leaves; "Keep the fire burning."
- **Each dawn:** a story card. The siblings talk, they find a clue, and
  the lantern gets one stage brighter.
- **Ending (win):** at the last dawn the kids find **mum's lantern** at
  the treeline. It is cold and empty. The ending is a cliffhanger:
  "She went deeper. We have to finish the Moon Lantern."
- Winning unlocks Chapter 2 (041).

### Chapter 2: "Into the Hollow" (7 Nights)
- **Intro:** the kids decide to stay and finish the Moon Lantern.
- **Dawn cards:** journal fragments and growing danger. From night 5, the
  Hollow King's eyes appear at the treeline.
- **Final night:** the Hollow King comes to the camp (038).
- **True ending:** the lantern is lit and the King shrinks into a small,
  warm shadow that curls up by the fire. The moon comes back and **mum
  walks out of the woods**. The final card shows the family by the fire.

### Defeat
A defeat is a story beat, not an error. The end screen shows a line
for the reason:
- The fire went out: "The dark came in... but the moon will rise again.
  Try again?"
- The played hero was knocked out: "[Hero] was too tired to stand.
  [Companion] will need you tomorrow."

## Cast and voice

| Character | Voice | Example line |
|---|---|---|
| **Leo** | Brave, impulsive, jokes when scared. | "Stay behind me, Nela! ...Okay, maybe next to me." |
| **Nela** | Clever, wry, notices things. | "Those imps only come where it's dark. Light means safe." |
| **Mum** | Only in journal pages: calm, curious, a ranger's notes. | "Day 3. The moss glows where the shards fell. I think the moon is asking for help." |
| **Hollow King** *(working)* | No words. Sounds, eyes and one final sigh. | |

Lines are keyed by **who is played**. Leo played gets Nela's replies,
and the other way round (feature 034's party). A future third hero just
adds their own lines.

## Writing rules for content files

- Every line has an id, so lines can be translated and reused:
  `dawn.c1.n1.leo`.
- Lines with a party placeholder use `{hero}` and `{companion}`, like
  `UiKit.party_text()`.
- No line longer than about 60 characters on a card. Barks stay under
  about 30.

## Open questions for the team

- Mum (ranger) or Grandpa as the missing adult?
- The boss name: Hollow King, Shadow Stag, Moon-Eater?
- New paintings: intro (3&ndash;4 cards), the two chapter endings, and the
  journal page frame. Can the team paint these, or should we reuse the
  existing loading art at first?
- Voiced lines, or text and sounds only?
