# Story bible: "The Dark Moon"

> Companion to [`game-design-spec.md`](game-design-spec.md). Status:
> features 035&ndash;042, see
> [`docs/roadmap/roadmap.md`](../roadmap/roadmap.md). **In the game:** the
> story frame (035: intro, dawn cards, endings, defeat lines), the
> Moon Lantern (036), the sibling barks (037), Mum (043), the
> Moon-Eater (038) and the story polish pass (046: Mum's notes on the
> dawn cards, the creatures' place in the story, named places). The rest
> is planned. Decided with the user
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
  idea per card and at most two lines of dialogue at a time, plus one
  of Mum's notes on a dawn card.
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

### Three lights (keep them apart)

- **The moon's light.** The Moon-Eater swallowed it. The Glow Shards are
  bits of it.
- **Mum's lantern**, her ranger lantern. The Moon-Eater drank its light
  too. The kids find it cold at the edge of the trees (Chapter 1
  ending), carry it home and hang it by the tent. In the true ending it
  flickers back on, just before Mum comes home.
- **The Moon Lantern**, the old stone lantern by the tent. The first
  rangers built it long ago to keep the Hollow Wood calm. The kids fill
  it with shards. Always call it "the Moon Lantern" (or "the lantern by
  the tent"), never "Mum's lantern".

### The creatures: lost things

Everything the dark brings is something the forest lost. None of them
is evil; each wants something.

| Creature | What it is | Why it comes |
|---|---|---|
| **Shadow Imp** | A lost shadow: an old path, a forgotten corner. | It is cold and crowds toward light. Torches and moonlight sting it. |
| **Bramble Beast** | A fallen tree, woken up angry by the dark. | It wrecks what people build: walls, fences, posts (the things made of its wood). |
| **Mushroom Gremlin** | A forest collector. | It carries shiny things to the Hollow, as gifts for the Moon-Eater (the lost things in its chest). Catch it and it drops them. |
| **Moon-Eater** | The biggest and loneliest lost thing. | It swallowed the moon to keep warm. Calmed, it becomes a small warm golem. |

The shards: imps and beasts carry crumbs of the swallowed moonlight, and
drop them when they are beaten.

### Places

The names the player sees (dawn cards, item text, loading tips). The map
is `game/scripts/world/world_layout.gd`.

| Place | Where | What is there |
|---|---|---|
| **The camp** | The clearing in the middle | Campfire, tent, the Moon Lantern, the well. |
| **Pine Grove** | NW | Pines and an old giant pine. Wood. |
| **Stony Pond** | NE | The pond, rocks, clay banks. Stone and clay. Mum's boot prints. |
| **Woodcutters' Glade** | SW (the "Woodlot") | Broadleaf trees, old stumps, a woodpile. Wood. |
| **Fairy Ring** | SE | Berry bushes round a giant old stump in a ring of toadstools. Berries. |
| **The Old Road** | Out south | Junk the old campers left: scrap. |
| **The Hollow** | Deep in the woods, never on the map | Where Mum went, and where the Moon-Eater lives. |

## The mystery (revealed across runs)

| Layer | What the player learns | Where |
|---|---|---|
| 1 | The Glow Shards the shadows drop are **pieces of the moon's light**. | First shard pickup (035/036) |
| 2 | Long ago the first rangers built a **Moon Lantern** by the camp, and it kept the Hollow Wood calm at night. Someone has to fill it again. | Dawn cards, Chapter 1 nights 1&ndash;2 (035, 046) |
| 3 | Mum knew about the lantern: the kids find **pages of her notebook** around the camp. | Mum's notes on the dawn cards (046); collected in a journal later (041) |
| 4 | The shadows are not evil. They are made of **everything the forest lost** (fallen trees, lost toys, forgotten paths) and they are cold, so they crowd toward light. | Mum's notes, Chapter 2 nights 2&ndash;3 (046); creature banners and loading tips |
| 5 | At the heart of the Hollow sits the **Moon-Eater**. It is the biggest, loneliest lost thing. It swallowed the moon's light, and drank the light of Mum's lantern, to keep from being cold. | Mum's notes, nights 5&ndash;6; Chapter 2 finale (038) |

### Mum's notes (046)

One page of Mum's notebook on each dawn card from Chapter 1 night 2 on,
read in her voice (`speaker: "note"`, a Mum `face`). The kid's line
before it says they found a page. These are the source of truth.

| Dawn | Face | Note |
|---|---|---|
| C1 n2 | curious | The rangers' old Moon Lantern kept the Hollow calm once. |
| C2 n1 | worried | Bits of moon in the moss. Something is breaking the light. |
| C2 n2 | curious | The shadows aren't wicked. They're lost things, and cold. |
| C2 n3 | surprised | Gremlins carry shiny things into the Hollow. Like gifts. |
| C2 n4 | smile | Near the old lantern, the woods breathe easier. |
| C2 n5 | worried | Something big in the Hollow eats light to keep warm. |
| C2 n6 | proud | Light the lantern all the way. The big one is just lonely. |

## Run structure: chapters

The two run lengths become chapters of one story.

### Chapter 1: "The Dark Moon" (3 Nights)
- **Intro:** mum leaves; "Keep the fire burning."
- **Each dawn:** a story card. The siblings talk and find a clue (from
  night 2, a page of Mum's notebook). The lantern brightens only when the
  kids bring it shards, so the cards never claim it is brighter.
- **Ending (win):** at the last dawn the kids find **mum's lantern** at
  the edge of the trees. It is cold: its light is gone. The ending is a
  cliffhanger: "She went deeper. Into the Hollow." / "We'll keep her
  lantern safe. And we'll find her."
- Winning unlocks Chapter 2 (041).

### Chapter 2: "Into the Hollow" (7 Nights)
- **Intro:** Mum's lantern hangs cold by the tent; the kids decide to
  stay and finish the Moon Lantern. It reads right without Chapter 1.
- **Dawn cards:** Mum's notes and growing danger: her boot prints by
  Stony Pond lead into the Hollow (night 3). From night 5, the
  Moon-Eater's eyes appear at the treeline.
- **Final night:** the Moon-Eater comes to the camp (038). The night
  does not end while it stands. It stomps and sweeps (the ground shows
  where), calls imp packs and blows out the torches, and at the end it
  reaches for the Moon Lantern: the brighter the lantern, the longer the
  kids have to calm it. It is never killed.
- **True ending:** the lantern is lit, the Moon-Eater lets the moon go:
  it falls apart into a heap of planks and stones, the crescent rises
  out of the heap into a beam of moonlight and the lost things float up
  and fade. Then a small, warm golem climbs out of the rubble and curls
  up by the fire. Mum's lantern flickers back on, and **mum
  walks out of the woods** (from the Hollow, where the boot prints
  went). The final card shows the family by the fire. The book is three
  pages: the Moon-Eater falls apart; the little golem ("It wasn't bad.
  It was just cold. And lonely."); Mum comes home ("My brave ones. You
  kept the fire burning.").

### Defeat
A defeat is a story beat, not an error. The end screen shows a line
for the reason:
- The fire went out: "The dark came in... but the moon will rise again."
- The played hero was knocked out: "[Hero] was too tired to stand.
  [Companion] needs you tomorrow."
- The end screen's Again button is the "try again".

## Cast and voice

| Character | Voice | Example line |
|---|---|---|
| **Leo** | Brave, impulsive, jokes when scared. | "Stay behind me, Nela! ...Okay, maybe next to me." |
| **Nela** | Clever, wry, notices things. | "Those imps only come where it's dark. Light means safe." |
| **Mum** | In the intro and the true ending, and in her notes on the dawn cards (046): calm, curious, warm, a ranger's notes. Her storybook portraits are the sheet's six expressions. | "The shadows aren't wicked. They're lost things, and cold." |
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
  `smile`, `curious`, `laugh`, `surprised`, `worried` or `proud`). `speaker` is `leo`, `nela`, `mum`,
  `narrator` or `note` (a page of Mum's notebook: shown as "Mum's note"
  with her face, in quotes, read in her voice); the optional `when` shows the line only when that hero is
  played. Dawn cards have one pair of lines per played hero: the
  played hero speaks first and the companion replies. A note line has
  no `when`, so it follows either pair.
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
  | Mum's notes | `af_heart`, as Mum | 0.88, a little slower | none | ~200 Hz |

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
cooldown, `urgent`, and `once` (`"night"`, or `"run"`: `first_beast`
barks only for the first beast of a run).

- Triggers: `low_hp`, `thief`, `thief_caught`, `thief_escaped` (a
  gremlin got home with its loot, 046), `first_beast`, `level_up`,
  `sunset`, `night_start`, `lantern_stage`, `companion_down`,
  `companion_up`, `danger_behind` (the companion's "Behind you!"), and
  the Moon-Eater's `boss` (it rises) and `boss_lantern` (it reaches for
  the lantern).
  Dawn has no bark, because every dawn already has its story card.
- The barks carry the lore too: gremlins run "to the Hollow", the beast
  is "that old tree", imps "just want our warm fire". The two heroes
  never share a line.
- At least two lines per hero for every trigger, at most 30 characters,
  and no placeholders (write one line per hero). `tools/check.sh` fails
  anything else.
- No chatter: 6 s between barks, a cooldown per trigger, and nothing
  while a story card or book is open. Hurt, knocked out, danger and
  level-up are urgent and skip the 6 s gap.

## Art plan

- **Received (047): the storybook paintings.** One painting per intro and
  ending page (12), in the team's style, generated from the art brief
  (`.features/047-story-art`). Sources are in `art/ui/source/story/`, and
  `art/ui/story_art.py` writes the game's 1600×900 copies to
  `assets/ui/story/story_<page>.webp`. The Chapter 2 intro painting
  showed Mum's lantern lit, so the script retouches it cold
  (`cold_lantern`; the original is kept as `c2_1_lit.webp`). The camping
  and Moon Lantern paintings double as loading screens.
- **The kids' faces (047):** six each, like Mum's, cut into round
  portraits (`assets/ui/story/<hero>_<face>.png`) and picked with `face` on
  their lines. Nela's surprised, worried and laugh were painted as heads;
  the rest are cut from the kids' faces in the storybook paintings
  (`story_art.py` `KID_FACES`), so they stay in the same style. A painted
  head can replace any of them later.
- **Mum's notebook (047):** a blank journal page and a sketch for each of
  her seven notes, shown beside the note on the dawn card (`sketch` on the
  line). The sketches are the team's painted pages, ink and watercolour
  on cream paper (`art/ui/source/notebook/`): the rangers round the old
  lantern, shards in the moss, the imp and the stump and log it was made
  from, a gremlin with a spoon and a button, a lantern glowing in the
  woods, eyes in the Hollow, and the Moon-Eater alone with its lost things.
  `art/ui/notebook_art.py` tidies their edges and pins each to the card
  with tape. The 041 journal can use the same page and sketches.
- **Lifted pages:** where the text band covered a face (the dark moon, the
  shadows, the lantern by the tent) or the found lantern, `story_art.py`
  raises the painting a little over a soft, blurred extension of itself.
- **Received (047): the Moon Lantern and the little golem.** Both are 3D
  models after their sheets (`16_moon_lantern_sheet.webp`,
  `18_little_golem_sheet.webp`): the lantern by the tent (shards stack up
  inside its glass, its carved crescent lights up near the top stage), and
  the little golem that climbs out of the Moon-Eater's heap, curls up by
  the fire and sits by the title fire once Mum is home. Mum's lantern
  sheet (`17_mum_lantern_sheet.webp`) is reference for a later prop.
- The Moon-Eater is a baked model after its character sheet (below), with
  tween clips (`moon_eater_visual.gd`).
- **Received:** Mum's character sheet (feature 043). Her six expressions
  are her storybook portraits (`assets/ui/story/mum_<face>.png`, picked
  per line with `face`), and she is a 3D model on the kids' rig
  (`art/characters/mum.py`): she walks home in the true ending and sits
  by the title fire afterwards.
- **Received:** the Moon-Eater's character sheet (2026-10-18,
  `art/reference/concept-2026-10/15_moon_eater_character_sheet.webp`).
  It is a **golem**: a hulking, hunched heap of weathered planks and
  stacked stones lashed with rope, about 3× a beast. Short stone legs,
  long ape-like arms with huge stone fists, and a small plank head set
  low between the shoulders, with two amber eyes (one bigger). Its chest
  is a round window of golden moonlight with a crescent, and the lost
  things it hoards float in it (a little chair, a teddy, a pocket
  watch, stars). Lanterns, brass bells, keys, a pocket watch and red
  plaid scarves hang off it; moss, saplings, fence pickets and
  branches grow on its back. Palette: dusk navy and purple-grey, weathered
  brown wood, then orange, amber, gold and cream for the glow. The game
  model is built and baked after it (`art/characters/moon_eater.py`).
- **Later, from the team:** the journal page frame; hand-made Moon-Eater
  animations. Each feature swaps its art in when it arrives, without
  changing code. The art is data: painting textures on `StoryBeat`, and a
  model scene with clips on the mob definition.

## Open questions for the team

- None right now. Next to collect: a real voice cast and recordings to
  replace the generated placeholders (line ids: the story and bark
  `.tres` files).
