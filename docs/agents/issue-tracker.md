# Issue tracker: Local Markdown

Issues and specs for this repo live as markdown files in `.scratch/`.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`, never a single combined tickets file
- Triage state is recorded as a `Status:` line near the top of each issue file (see `triage-labels.md` for the role strings)
- Comments and conversation history append to the bottom of the file under a `## Comments` heading

## When a skill says "publish to the issue tracker"

Create a new file under `.scratch/<feature-slug>/` (creating the directory if needed).

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or the issue number directly.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a file with one **child** file per ticket.

- **Map**: `.scratch/<effort>/map.md` (the Notes / Decisions-so-far / Fog body).
- **Child ticket**: `.scratch/<effort>/issues/NN-<slug>.md`, numbered from `01`, with the question in the body. A `Type:` line records the ticket type (`research`/`prototype`/`grilling`/`task`); a `Status:` line records `claimed`/`resolved`.
- **Blocking**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked when every file it lists is `resolved`.
- **Frontier**: scan `.scratch/<effort>/issues/` for files that are open, unblocked, and unclaimed; first by number wins.
- **Claim**: set `Status: claimed` and save before any work.
- **Resolve**: append the answer under an `## Answer` heading, set `Status: resolved`, then append a context pointer (gist + link) to the map's Decisions-so-far in `map.md`.

## Campsite notes

- `.scratch/` is **committed**, so specs and tickets are shared through git like any other docs. Commit ticket updates with the work they track.
- A spec carries a `Status:` line too. A feature is done when every ticket is `Status: done` (or `wontfix`). Then set the spec to `Status: done`, and update the feature's row in `docs/roadmap/roadmap.md`.
- Tickets that need a person (hand play, a kid playtest, a Windows build) are `ready-for-human`. The standing list is `.scratch/hand-play-backlog/`.
- Features 000&ndash;048 predate this tracker. Their five-file folders are archived, read-only, in `docs/history/features/`. Link to them for background, but don't edit them.
- **Building tickets in parallel** (`/implement-spec`): when the integration branch hasn't moved since an implementer merged it in, its branch fast-forwards onto a tree `tools/check.sh` already passed, so fast-forward it directly. Send a merger, which runs the checks again, only for a true merge.
- **Hand-play ticket numbers** are claimed at merge, not when drafting: tickets built in parallel draft theirs as `NN-slug.md`, and whoever merges gives it the next free number in `.scratch/hand-play-backlog/issues/` and lists it in that spec.
