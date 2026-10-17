# Feature 035: Story frame (plan)

Status: **planned** (roadmap from the 2026-10 brainstorm). Rough size: **M**.

## Goal
Give a run a beginning, a middle and an end. It follows [`docs/design/story.md`](../../docs/design/story.md): mum has gone into the Hollow Wood, the moon is dark, and the kids hold the fire.

## Scope
- **Intro storybook.** It plays after hero select and before loading, or over the loading screen. It has 3–4 painted cards with one or two lines each. Click, Space or Enter goes to the next card, and Esc skips. It is shown once per chapter and replays from the title screen's Story button (041).
- **Dawn cards.** At each dawn a card slides in with a short sibling dialogue (hero/companion lines from feature 034's party) and a hint about the next night. It must not block play: it fades by itself after about 6 s, or on a click.
- **Chapters.** 3 Nights is **Chapter 1, "The Dark Moon"**, and 7 Nights is **Chapter 2, "Into the Hollow"**. The title buttons get the chapter names, and the night counts move to the subtitles.
- **Endings.** On a win, the end screen shows the chapter's ending card first and the stats after. On a defeat, the reason is finally shown as a story line ("The dark came in...").

## Systems touched
- New: `scripts/story/story_beat.gd` (a Resource: id, painting, lines, condition) and `resources/story/*.tres`. New: `scripts/ui/story_card.gd` (a canvas card in the `UiKit` campcraft style).
- `scripts/core/game_manager.gd`: `chapter()` derived from `nights_to_win`; the flow becomes hero select, then the intro, then loading.
- `scripts/core/time_manager.gd`: the `dawn_started` signal drives the dawn card. `scripts/ui/hud.gd` hosts the card above the banner.
- `scripts/ui/end_screen.gd`: uses the `reason` argument that `_on_run_ended` ignores today, plus an ending card.
- `scripts/ui/ui_kit.gd`: `party_text()` fills `{hero}` and `{companion}` in the lines.
- The paintings reuse `loading_screen.gd`'s art at first, until the team paints new ones.

## Data shape
`StoryBeat { id, chapter, trigger (intro | dawn | win | loss_fire | loss_hero), night, painting, lines: Array[{speaker: hero|companion|narrator, text}] }`

## Depends on
034 (party). The lantern lines in the dawn cards land with 036.
