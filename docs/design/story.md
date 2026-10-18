# Story bible: "The Dark Moon"

> Companion to [`game-design-spec.md`](game-design-spec.md). Status:
> features 035&ndash;042, see
> [`docs/roadmap/roadmap.md`](../roadmap/roadmap.md). **In the game:** the
> story frame (035: intro, dawn cards, endings, defeat lines), the
> Moon Lantern (036), the sibling barks (037), Mum (043) and the
> Moon-Eater (038). The rest is planned. Decided with the user
> (2026-10): the missing adult is **Mum**, the boss is the **Moon-Eater**,
> the team provides concept art and animations later (see the Art plan),
> and the characters get **voiced lines** (see Voice).

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
their **mum**, a forest ranger. Her look is the team's character sheet
(`art/reference/concept-2026-10/14_mum_character_sheet.webp`): long wavy
blond hair in a loose low bun, a lime ranger jacket over a black top, a tan
scarf, cargo trousers, red-laced boots and an olive pack. The beagle on the
sheet is concept flavour only, not part of the story.

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
| 5 | At the heart of the Hollow sits the **Moon-Eater**. It is the biggest, loneliest shadow. It swallowed the moon's light, and mum's lantern with it, to keep from being cold. | Chapter 2 finale (038) |

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
  Moon-Eater's eyes appear at the treeline.
- **Final night:** the Moon-Eater comes to the camp (038). The night
  does not end while it stands. It stomps and sweeps (the ground shows
  where), calls imp packs and blows out the torches, and at the end it
  reaches for the Moon Lantern: the brighter the lantern, the longer the
  kids have to calm it. It is never killed.
- **True ending:** the lantern is lit, the Moon-Eater lets the moon go and shrinks into a small,
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
| **Mum** | In the intro and the true ending, and in her journal pages (041): calm, curious, warm, a ranger's notes. Her storybook portraits are the sheet's six expressions. | "Day 3. The moss glows where the shards fell. I think the moon is asking for help." |
| **Moon-Eater** | No words. Sounds, glowing eyes, a belly full of swallowed moonlight, and one final sigh. | |

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
- Content lives in `game/resources/story/*.tres` (`StoryBeat`). A line is
  `{id, speaker, text, when, face}` (`face`: one of Mum's expressions,
  `smile`, `curious`, `laugh`, `surprised`, `worried` or `proud`). `speaker` is `leo`, `nela`, `mum` or
  `narrator`; the optional `when` shows the line only when that hero is
  played. Dawn cards have one pair of lines per played hero: the
  played hero speaks first and the companion replies.
- Voiced lines avoid `{hero}`/`{companion}`, because a recording can't
  change its words. Write one `when` variant per hero instead (see
  `loss.hero.leo` and `loss.hero.nela`).
- `tools/check.sh` fails a line over 60 characters, an unknown speaker or
  placeholder, a duplicate id, or a beat with no lines for one of the
  heroes.

## Voice

Decided: the characters get **voiced lines**. Leo, Nela, Mum and the
narrator speak every story line; the Moon-Eater stays wordless (sounds
only, 038).

- One recording per line, named by the line id:
  `game/assets/audio/voice/<line id>.ogg`. See the README in that folder.
- The game plays them on its own **Voice** bus, one line after another.
  A card stays up until its voices have finished (at least 6 s at dawn).
- For now every line is a **generated placeholder** (Kokoro TTS,
  `art/audio/voice.py`, `tools/build_audio.sh voice`). A real recording
  with the same name replaces one. A line without any file shows as
  text only; the validator reports how many lines are voiced.
- The generated cast (the `CAST` table; pitch is the measured median):

  | Speaker | Kokoro voice | Speed | Shift | Pitch |
  |---|---|---|---|---|
  | Leo (7) | `am_liam` + `af_aoede` (a boy: male and female blended) | 1.05, quick | +4 semitones | ~210 Hz |
  | Nela (3) | `af_jessica` + `af_bella` | 0.95, deliberate | +2.5 semitones | ~245 Hz |
  | Mum | `af_heart`, warm | 0.92 | none | ~205 Hz |
  | Narrator | `bm_fable`, a British storyteller | 0.9 | none | ~135 Hz |

  The names are said the German way: Nela [ˈneːla] ("NAY-lah"), Leo
  [ˈleːo] ("LAY-oh"); `NAMES` in `voice.py` swaps them into the
  phonemes. Kokoro has no child voices, so Nela is a young woman's
  voice and Leo blends a young male voice with a female one (a female
  base alone sounded like a woman, not a boy). Both are shifted up,
  formants included (a smaller vocal tract); more than this sounded
  too high and chipmunky.
- Barks (037) follow the same rule: `bark.<trigger>.<speaker>.<n>.ogg`.
  Until a bark has a recording, a short chirp plays in the speaker's
  pitch (`chirp_leo`, `chirp_nela`).

## Barks (037)

Short lines over a sibling's head while you play, in
`game/resources/barks/barks.tres` (`BarkSet`). A line is
`{id, trigger, speaker, text, when}` and the set tunes each trigger:
who speaks (`hero`, `companion`, `subject` or `call_response`), its
cooldown, `urgent`, and `once: "night"`.

- Triggers: `low_hp`, `thief`, `thief_caught`, `first_beast`, `level_up`,
  `sunset`, `night_start`, `lantern_stage`, `companion_down`,
  `companion_up`, `danger_behind` (the companion's "Behind you!"), and
  the Moon-Eater's `boss` (it rises) and `boss_lantern` (it reaches for
  the lantern).
  Dawn has no bark, because every dawn already has its story card.
- At least two lines per hero for every trigger, at most 30 characters,
  and no placeholders (write one line per hero). `tools/check.sh` fails
  anything else.
- No chatter: 6 s between barks, a cooldown per trigger, and nothing
  while a story card or book is open. Hurt, knocked out, danger and
  level-up are urgent and skip the 6 s gap.

## Art plan

- **For now, placeholders.** Story cards reuse the existing loading-screen
  paintings, and new models (Moon Lantern, Moon-Eater) start as
  code-built stand-ins in the 031 style. The Moon-Eater stand-in has
  its eyes, moonlit hollow belly and lost things (a teddy, a boot,
  branches), with tween clips (`moon_eater_visual.gd`).
- **Received:** Mum's character sheet (feature 043). Her six expressions
  are her storybook portraits (`assets/ui/story/mum_<face>.png`, picked
  per line with `face`), and she is a 3D model on the kids' rig
  (`art/characters/mum.py`): she walks home in the true ending and sits
  by the title fire afterwards.
- **Later, from the team:** intro and chapter-ending
  paintings; the journal page frame; Moon-Eater concept art and
  animations. Each feature swaps its art in when it arrives, without
  changing code. The art is data: painting textures on `StoryBeat`, and a
  model scene with clips on the mob definition.

## Open questions for the team

- None right now. Next to collect: a real voice cast and recordings to
  replace the generated placeholders (line ids: the story and bark
  `.tres` files).
