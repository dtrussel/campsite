# Feature 047: Story art (plan)

Status: **done**. Rough size: **M**.

## Goal
Put the team's new artwork into the game. The art was generated from the brief written after 046 (the prompt in the 046 conversation, summarised in `docs/design/story.md`, Art plan).

## What arrived
- **12 storybook paintings** (2560×1440), one per intro and ending page.
- **3 of Nela's expressions** (surprised, worried, laugh).
- **Concept sheets:** the Moon Lantern, Mum's lantern and the little golem.
- **Not delivered:** Leo's expressions, Nela's other three, and Mum's notebook pages.

## Decisions taken with the user
- Build the **Moon Lantern** and the **little golem** as 3D models now. Mum's lantern sheet is stored as reference only.
- **Retouch** the Chapter 2 intro painting so Mum's lantern is cold, as the text says.

## Work
1. **Sources:** `art/ui/source/story/*.webp`, `art/ui/source/nela_*.webp`, and the sheets 16–19 in `art/reference/concept-2026-10/`.
2. **`art/ui/story_art.py`:**
   - writes the paintings at 1600×900 (`PAINTINGS`, with an optional `lift`);
   - writes `cold_lantern` for c2_1;
   - cuts the kids' faces (`KID_FACES`).
3. **Data and code:**
   - each intro and win beat points to its painting;
   - Nela's lines carry `face`;
   - `StoryLibrary.speaker_portrait` and `hero_face_path` serve the kids' faces;
   - the validator checks hero faces and that pages use their own painting;
   - two paintings become loading screens.
4. **Moon Lantern:**
   - `art/props/camp.py` `moon_lantern` (2.4k tris);
   - `moon_lantern.gd` instances it and adds glass, shards inside, a core and a crescent glow decal.
5. **Little golem:**
   - `art/characters/little_golem.py` (6.2k tris);
   - `scripts/story/little_golem.gd` (breathing, `curl_up`);
   - `MoonEaterVisual._reassemble_small` uses it, and `BossController` curls it up by the fire;
   - `TitleBackdrop` seats it by the title fire once Mum is home.
6. **Docs:** `story.md` Art plan, `art-direction.md`, `art/README.md`, the concept README and the roadmap.
