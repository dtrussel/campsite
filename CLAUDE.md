# Campsite: notes for Claude

A Godot 4.3 game (`game/`) with procedural Blender art (`art/`). Docs
live in `docs/`, and work is tracked as local markdown issues in
`.scratch/<feature-slug>/`. Run the checks with `tools/check.sh`.

## Read before you start

- **Modelling a character** (a hero, Mum, an NPC or a creature in
  `art/characters/`), or changing its proportions, face, hair or
  clothes: read
  [`docs/design/character-modelling.md`](docs/design/character-modelling.md)
  first. It covers the measured render-and-compare loop, the proportion
  targets, the tools (`art/lib/measure.py`, `MEASURE=1`, `HEAD_ONLY=1`)
  and the gotchas.
- **Any art work:** [`art/README.md`](art/README.md) for the pipeline
  and budgets, and
  [`docs/design/art-direction.md`](docs/design/art-direction.md) for the
  look.
- **Story content:** [`docs/design/story.md`](docs/design/story.md).

## Workflow

Matt Pocock's skills (`mattpocock-skills`) are enabled in
`.claude/settings.json`.

- **Larger work:** align with `/grill-with-docs`, write it up with
  `/to-spec`, split it with `/to-tickets`, then build it with
  `/implement`.
- **Between sessions:** use `/handoff`.
- **The issue queue:** use `/triage` to walk it.
- **When you finish a ticket:** set its `Status:` and note the outcome
  under `## Comments`. Keep `docs/` (design, roadmap, `art/README.md`)
  in sync when the work changes them.
- **Small fixes:** these need no spec or ticket; a commit is enough.
- **After a push:** start watching CI on the head commit in the
  background (a background agent or command) and carry on with other
  work meanwhile; don't report the work done until it is green. A
  local green `tools/check.sh` does not cover the export.
- **Features 000–048:** they are archived, read-only, in
  `docs/history/features/`.

## Agent skills

### Issue tracker

Local markdown in `.scratch/<feature-slug>/`: a `spec.md` plus
`issues/NN-slug.md` tickets, committed. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default roles (`needs-triage`, `needs-info`, `ready-for-agent`,
`ready-for-human`, `wontfix`), written as the `Status:` line. See
`docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` at the root and
`docs/adr/`. See `docs/agents/domain.md`.
